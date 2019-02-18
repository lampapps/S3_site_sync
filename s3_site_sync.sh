#!/bin/bash

# credits: based on savjee.be/_deploy.sh at github
# https://github.com/Savjee/savjee.be/blob/1a84362c4424ecd2ee7d368298ed30c218a2d66a/_deploy.sh

#Updated to build and sync Jeykll site

##
# Options
##

AWS_PROFILE='default'
STAGING_BUCKET='test.'
LIVE_BUCKET='www.'
SITE_DIR='_site/'
REGION='us-east-1'
CLOUDFRONTID='enterid from cloudfront'
INDEX_PAGE='index.html'
ERROR_PAGE='error.html'


##
# Usage
##
usage() {
cat << _EOF_
Usage: ${0} [staging | live]
    
    staging		Deploy to the staging bucket
    live		Deploy to the live (www) bucket
_EOF_
}
 
##
# Color stuff
##
NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2; tput bold)
YELLOW=$(tput setaf 3)

function red() {
    echo "$RED$*$NORMAL"
}

function green() {
    echo "$GREEN$*$NORMAL"
}

function yellow() {
    echo "$YELLOW$*$NORMAL"
}

##
# Actual script
##

# Expecting at least 1 parameter
if [[ "$#" -ne "1" ]]; then
    echo "Expected 1 argument, got $#" >&2
    usage
    exit 2
fi

if [[ "$1" = "live" ]]; then
	BUCKET=$LIVE_BUCKET
	green 'Deploying to live bucket'

    elif [[ "$1" = "staging" ]]; then
    BUCKET=$STAGING_BUCKET
    green 'Deploying to staging bucket'
    # create and configure the bucket to be a website
    yellow '--> Creating a static website bucket'
    aws s3api create-bucket --bucket $BUCKET --region $REGION --profile $AWS_PROFILE
else
    echo "Expected 1 argument, got $#" >&2
    usage
    exit 2
fi


#echo $BUCKET

aws s3 website $BUCKET --index-document $INDEX_PAGE --error-document $ERROR_PAGE --profile $AWS_PROFILE

# Build the site in the Jekyll site folder
yellow '--> Running Jekyll build'
jekyll build

yellow '--> Uploading css files'
aws s3 sync $SITE_DIR s3://$BUCKET --exclude '*.*' --include '*.css' --content-type 'text/css' --cache-control 'max-age=604800' --acl public-read --delete --profile $AWS_PROFILE


yellow '--> Uploading js files'
aws s3 sync $SITE_DIR s3://$BUCKET --exclude '*.*' --include '*.js' --content-type 'application/javascript' --cache-control 'max-age=604800' --acl public-read --delete --profile $AWS_PROFILE

# Sync media files first (Cache: expire in 10weeks)
yellow '--> Uploading images (jpg, png, ico)'
aws s3 sync $SITE_DIR s3://$BUCKET --exclude '*.*' --include '*.png' --include '*.jpg' --include '*.ico' --expires 'Sat, 20 Nov 2025 18:46:39 GMT' --cache-control 'max-age=6048000' --acl public-read --delete --profile $AWS_PROFILE


# Sync html files (Cache: 2 hours)
yellow '--> Uploading html files'
aws s3 sync $SITE_DIR s3://$BUCKET --exclude '*.*' --include '*.html' --content-type 'text/html' --cache-control 'max-age=7200, must-revalidate' --acl public-read --delete --profile $AWS_PROFILE


# Sync everything else
yellow '--> Syncing everything else'
aws s3 sync $SITE_DIR $BUCKET --delete --cache-control 'max-age=7200, must-revalidate' --acl public-read --delete --profile $AWS_PROFILE

if [[ "$1" = "live" ]]; then
    # Remove staging bucket to clean up things
    yellow '--> Removing staging bucket '$STAGING_BUCKET
    aws s3 rb s3://$STAGING_BUCKET --force
    yellow '--> Invalidating all objects on Cloudfront forcing the cache to refresh from origin'
    aws cloudfront create-invalidation --distribution-id $CLOUDFRONTID --paths "/*"
    green 'Deployed to live bucket. Do not forget to turn on gzip in AWS Cloudfront and to set custom error pages 404 and 403'

    elif [[ "$1" = "staging" ]]; then
    #return the url of the website
    green 'http://'$BUCKET'.s3-website-'$REGION'.amazonaws.com/index.html'
fi





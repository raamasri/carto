#!/bin/bash

# CARTO Complete Deployment Script
# Usage: ./scripts/deploy.sh "commit message"

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage: ./scripts/deploy.sh \"commit message\"${NC}"
    echo -e "${YELLOW}Example: ./scripts/deploy.sh \"Fixed login bug\"${NC}"
    exit 1
fi

COMMIT_MESSAGE="$1"

echo -e "${BLUE}🚀 Starting complete CARTO deployment...${NC}"

# Step 1: Commit and push changes
echo -e "${BLUE}📝 Committing changes...${NC}"
git add .
git commit -m "$COMMIT_MESSAGE"

echo -e "${BLUE}☁️ Pushing to repository...${NC}"
git push

# Step 2: Deploy to TestFlight
echo -e "${BLUE}📱 Deploying to TestFlight...${NC}"
./scripts/deploy_testflight.sh

echo -e "${GREEN}🎉 Complete deployment finished!${NC}"
echo -e "${GREEN}✅ Code pushed to repository${NC}"
echo -e "${GREEN}✅ Build uploaded to TestFlight${NC}" 
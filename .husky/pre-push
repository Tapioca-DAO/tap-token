#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx npm-check-updates -u tapioca-sdk && npm i --no-package-lock
npm run test

#!/bin/bash

set -e

workdir=$(pwd)

build_types() {
  cd $workdir

  if [ ! -d "artifacts/src" ]; then
    # Mostly for local development
    npm run build:hh
  fi

  local target="$1"
  echo "Building target: $target"

  if [ -d ".build/package-$target" ]; then
      echo "Cleaning up build directory..."
      rm -rf ".build/package-$target" || echo "Failed to clean up build directory."
  else
      echo "Creating build directory..."
  fi

  mkdir -p ".build/package-$target" && cd ".build/package-$target"

  echo "Build directory created."

  cat <<EOF > package.json
    {
      "name": "@trustvc/document-store",
      "version": "1.0.0",
      "main": "index.js",
      "module": "index.mjs",
      "types": "./types/index.d.ts",
      "exports": {
        "types": "./types/index.d.ts",
        "require": "./index.js",
        "default": "./index.mjs"
      },
      "repository": "git+https://github.com/TrustVC/Document-Store.git",
      "license": "Apache-2.0",
      "publishConfig": {
        "access": "public"
      }
    }
EOF

  # Keep the package name as @trustvc/document-store without target suffix
  # jq --arg target "$target" '.name = "@trustvc/document-store-\($target)"' package.json > package.json.tmp && mv package.json.tmp package.json

  cp ../../README.md .

  sed -e 's|<p align="center">Document Store</p>|<p align="center">Document Store ('"$target"')</p>|' README.md > README.md.tmp && mv README.md.tmp README.md

  npm install "@typechain/$target" --save-dev --no-fund --no-audit

  npx --yes typechain --target $target --out-dir ./output '../../artifacts/src/**/*[^dbg].json'

  echo "Typechain build completed."

  npm install --no-save rollup-plugin-typescript2 @rollup/plugin-commonjs @rollup/plugin-node-resolve

  cp ../../rollup.config.mjs .

  npx --yes rollup -c

  mkdir -p types && mv .build/package-$target/output/* types/

  rm -rf .build output rollup.config.mjs

  echo "Bundling completed."

  echo "✅ Completed building for $target!"
}

publish_types() {
  cd $workdir

  local version="$1"
  echo "Publish version: $version"

  for folder in "$workdir"/.build/*; do
    if [ -d "$folder" ]; then
      # Unlikely, but skip if it is not folder
      cd "$folder" || continue

      jq ".version = \"$version\"" package.json > package.json.tmp && mv package.json.tmp package.json
      
      PACKAGE_NAME=$(jq -r '.name' package.json)

      echo "Updated $PACKAGE_NAME package.json to version $version."
      echo "📢 Publishing $PACKAGE_NAME package to NPM..."

      npm publish

      echo "🎉 Completed publishing $PACKAGE_NAME@$version to NPM!"
    fi
  done
}

if [ "$#" -ne 2 ]; then
    echo "Invalid number of arguments. Usage: build.sh {typechain|publish} target|version"
    exit 1
fi

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "All arguments are required. Usage: build.sh {typechain|publish} target|version"
    exit 1
fi

case "$1" in
    "typechain")
        build_types "$2"
        ;;
    "publish")
        publish_types "$2"
        ;;
    *)
        echo "Invalid command. Usage: build.sh {typechain|publish} target|version"
        exit 1
        ;;
esac

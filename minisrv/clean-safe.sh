#!/usr/bin/env bash
echo "🧼 Killing java..."
taskkill.exe //F //IM java.exe > /dev/null 2>&1 || true

echo "🧹 Deleting target/"
rm -rf target/

echo "🔨 Building..."
mvn clean package

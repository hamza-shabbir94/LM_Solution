docker login -u hamza94
docker tag api-service:latest hamza94/production-api-service:1.0.0
docker push hamza94/production-api-service:1.0.0


docker tag api-service:latest hamza94/development-api-service:dev-latest
docker push hamza94/development-api-service:dev-latest

docker tag api-service:latest hamza94/staging-api-service:staging-latest
docker push hamza94/staging-api-service:staging-latest




docker build --platform linux/amd64 -t api-service:latest -f Dockerfile .

docker tag api-service:latest hamza94/staging-api-service:staging-latest
docker push hamza94/staging-api-service:staging-latest
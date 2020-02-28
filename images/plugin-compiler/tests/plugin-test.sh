
set -e
if [ -z "${TYK_DB_LICENSEKEY}" ];
then
  echo "TYK_DB_LICENSEKEY env variable not set";
  exit 1
fi

# Pull all necessary images
docker pull library/mongo:latest
docker pull bitnami/redis:latest
docker pull tykio/tyk-dashboard:v1.9.1
docker pull tykio/tyk-gateway:v2.9.1
docker pull docker.io/tykio/tyk-plugin-compiler:v2.9.1
# Start prerequisites
docker run -p 6379:6379 -e ALLOW_EMPTY_PASSWORD=yes -d --name tyk_redis bitnami/redis
docker run -p 27017:27017 -d --name tyk_mongo library/mongo:latest
# Build plugin
docker run -v `pwd`:/go/src/plugin-build docker.io/tykio/tyk-plugin-compiler:v2.9.1 plugin.so

# Store license in $TYK_DB_LICENSEKEY, then run containers
docker run -p 3000:3000 -d --name tyk_dashboard --link tyk_redis:redis --link tyk_mongo:mongo --add-host dashboard.tyk.docker:127.0.0.1 -e TYK_GW_SECRET=foo -e TYK_DB_LICENSEKEY=$TYK_DB_LICENSEKEY tykio/tyk-dashboard:v1.9.1
docker run -p 8080:8080 -d --name tyk_gateway -e TYK_GW_SECRET=foo --link tyk_redis:redis --link tyk_dashboard:dashboard -v $(pwd)/tyk.conf:/opt/tyk-gateway/tyk.conf -v $(pwd)/plugin.so:/opt/tyk-gateway/middleware_plugins/plugin.so tykio/tyk-gateway:v2.9.1

# Fill in the bootstrap data
curl -d "owner_name=rbs&owner_slug=rbs&email_address=admin@example.com&first_name=Tyk&last_name=Admin&password=Password1&confirm_password=Password1" -X POST http://localhost:3000/bootstrap

echo "Continue with manual creation of API on http://localhost:3000, user:admin@example.com, password=Password1"

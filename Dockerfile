FROM node:16 as build-deps
WORKDIR /opt/app

# cache hack; very fragile
# only copy files `yarn` needs to run
# avoids accidental cache invalidation by changes in code
COPY package.json yarn.lock ./
RUN yarn

COPY . .
RUN yarn build



FROM nginx as production
COPY docker-entrypoint.sh /usr/bin/docker-entrypoint.sh
# write environment variables to config file and start
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh", "/docker-entrypoint.sh"]

COPY --from=build-deps /opt/app/dist /usr/share/nginx/html

CMD ["nginx","-g","daemon off;"]

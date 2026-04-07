FROM node:18-alpine as front-build

COPY ./front /src

WORKDIR /src

RUN npm ci \
    && npx @angular/cli build --optimization

FROM gradle:jdk17 as back-build

WORKDIR /src

COPY back/src ./src
COPY back/gradle ./gradle
COPY back/gradlew back/gradlew.bat back/build.gradle back/settings.gradle ./

RUN sed -i 's/\r$//' gradlew
RUN chmod +x gradlew

RUN ./gradlew build

FROM alpine:3.19 as front

COPY --from=front-build /src/dist/microcrm/browser /app/front
COPY misc/docker/Caddyfile /app/Caddyfile

RUN apk add caddy

WORKDIR /app

EXPOSE 80
EXPOSE 443

CMD ["/usr/sbin/caddy", "run"]

FROM eclipse-temurin:21-jre-alpine as back

COPY --from=back-build /src/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/back/microcrm-0.0.1-SNAPSHOT.jar

WORKDIR /app

EXPOSE 4200

CMD ["java", "-jar", "/app/back/microcrm-0.0.1-SNAPSHOT.jar"]

FROM alpine:3.19 as standalone

COPY --from=front-build /src/dist/microcrm/browser /app/front
COPY --from=back-build /src/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/back/microcrm-0.0.1-SNAPSHOT.jar

COPY misc/docker/Caddyfile /app/Caddyfile
COPY misc/docker/supervisor.ini /app/supervisor.ini

RUN apk add --no-cache supervisor caddy openjdk21-jre

WORKDIR /app

CMD ["/usr/bin/supervisord", "-c", "/app/supervisor.ini"]




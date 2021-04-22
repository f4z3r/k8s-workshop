# Build image
FROM maven:3.8.1-jdk-8 AS maven

WORKDIR /app

COPY ./app/pom.xml ./pom.xml
RUN mvn dependency:go-offline -B

COPY ./app/src ./src
RUN mvn package


# Runtime image
FROM openjdk:8-jre

WORKDIR /app

RUN useradd -U spring
USER spring:spring

COPY --from=maven /app/target/sb-next-level-0.0.1-SNAPSHOT.jar ./sb-next-level-0.0.1-SNAPSHOT.jar

CMD ["java", "-jar", "./sb-next-level-0.0.1-SNAPSHOT.jar"]

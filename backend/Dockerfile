# Usa una imagen base con Maven y JDK 17
FROM maven:3.8.3-openjdk-17 AS build

# Establece el directorio de trabajo
WORKDIR /app

# Copia el archivo pom.xml
COPY pom.xml .

# Descarga las dependencias
RUN mvn dependency:go-offline -B

# Copia el código fuente
COPY src ./src

# Construye la aplicación
RUN mvn package -DskipTests

# Usa una imagen base ligera con JDK 17 para la imagen final
FROM openjdk:17-jdk-slim

# Establece el directorio de trabajo
WORKDIR /app

# Copia el JAR construido desde la etapa de construcción
COPY --from=build /app/target/*.jar app.jar

# Expone el puerto en el que se ejecuta tu aplicación
EXPOSE 8080

# Comando para ejecutar la aplicación
ENTRYPOINT ["java","-jar","app.jar"]
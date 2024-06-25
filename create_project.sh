#!/bin/bash

# Colores para mejor legibilidad
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Bienvenido al asistente de creación de proyecto AB Spring Boot + Vite + Docker${NC}"

# Función para preguntar sí o no
ask_yes_no() {
    while true; do
        read -p "$1 (s/n): " yn
        case $yn in
            [Ss]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Por favor responde sí o no.";;
        esac
    done
}

# Preguntar por el nombre del proyecto
read -p "Nombre del proyecto: " PROJECT_NAME

# Crear directorio del proyecto
mkdir $PROJECT_NAME && cd $PROJECT_NAME

# Backend con Spring Boot
echo -e "${YELLOW}Configurando el backend con Spring Boot...${NC}"
read -p "Versión de Spring Boot (default 2.5.5): " SPRING_BOOT_VERSION
SPRING_BOOT_VERSION=${SPRING_BOOT_VERSION:-2.5.5}

read -p "Grupo (com.example): " GROUP_ID
GROUP_ID=${GROUP_ID:-com.example}

read -p "Artefacto (demo): " ARTIFACT_ID
ARTIFACT_ID=${ARTIFACT_ID:-demo}

# Usar Spring Initializr para crear el proyecto
mkdir backend && cd backend
echo -e "${YELLOW}Descargando el proyecto Spring Boot...${NC}"
curl -o backend.zip https://start.spring.io/starter.zip \
    -d type=maven-project \
    -d language=java \
    -d bootVersion=$SPRING_BOOT_VERSION \
    -d baseDir=. \
    -d groupId=$GROUP_ID \
    -d artifactId=$ARTIFACT_ID \
    -d name=$ARTIFACT_ID \
    -d description="Demo project for Spring Boot" \
    -d packageName=$GROUP_ID.$ARTIFACT_ID \
    -d packaging=jar \
    -d javaVersion=11 \
    -d dependencies=web,data-jpa,h2

iif [ $? -eq 0 ]; then
    echo -e "${YELLOW}Verificando el archivo descargado...${NC}"
    if [ -f backend.zip ]; then
        echo "Tamaño del archivo:"
        ls -l backend.zip
        echo "Tipo de archivo:"
        file backend.zip
        echo "Primeros bytes del archivo:"
        head -c 20 backend.zip | xxd
        
        echo -e "${YELLOW}Intentando descomprimir el proyecto...${NC}"
        unzip -q backend.zip
        UNZIP_RESULT=$?
        if [ $UNZIP_RESULT -eq 0 ]; then
            rm backend.zip
            echo -e "${GREEN}Backend creado exitosamente${NC}"
        else
            echo -e "${RED}Error al descomprimir backend.zip. Código de error: $UNZIP_RESULT${NC}"
            echo "Contenido del archivo (primeras 10 líneas):"
            head -n 10 backend.zip
            exit 1
        fi
    else
        echo -e "${RED}El archivo backend.zip no existe${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error al descargar el backend. Por favor, verifica tu conexión a internet y los parámetros ingresados.${NC}"
    exit 1
fi
cd ..


# Frontend con Vite
echo -e "${YELLOW}Configurando el frontend con Vite...${NC}"
if ask_yes_no "¿Deseas usar Nx para el frontend?"; then
    npx create-nx-workspace@latest frontend --preset=react-standalone
else
    npm init vite@latest frontend -- --template react-ts
    cd frontend
    npm install
    cd ..
fi

echo -e "${GREEN}Frontend creado exitosamente${NC}"

# Docker
echo -e "${YELLOW}Configurando Docker...${NC}"

# Dockerfile para el backend
cat << EOF > backend/Dockerfile
FROM openjdk:11-jdk-slim
VOLUME /tmp
ARG JAR_FILE=target/*.jar
COPY \${JAR_FILE} app.jar
ENTRYPOINT ["java","-jar","/app.jar"]
EOF

# Dockerfile para el frontend
cat << EOF > frontend/Dockerfile
FROM node:14
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "run", "start"]
EOF

# docker-compose.yml
cat << EOF > docker-compose.yml
version: '3'
services:
  backend:
    build: ./backend
    ports:
      - "8080:8080"
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    depends_on:
      - backend
EOF

echo -e "${GREEN}Configuración de Docker completada${NC}"

# Configuración de GitHub
echo -e "${YELLOW}Configurando GitHub...${NC}"
if ask_yes_no "¿Deseas inicializar un repositorio de Git y subirlo a GitHub?"; then
    git init
    git add .
    git commit -m "Initial commit"
    
    read -p "Introduce el nombre de tu repositorio en GitHub: " REPO_NAME
    git remote add origin git@github.com:$GITHUB_USERNAME/$REPO_NAME.git
    
    echo -e "${YELLOW}Asegúrate de haber creado el repositorio '$REPO_NAME' en GitHub antes de continuar.${NC}"
    if ask_yes_no "¿Has creado el repositorio y estás listo para hacer push?"; then
        git push -u origin main
        echo -e "${GREEN}Repositorio subido a GitHub exitosamente${NC}"
    else
        echo -e "${YELLOW}No se ha realizado el push. Puedes hacerlo manualmente más tarde.${NC}"
    fi
else
    echo -e "${YELLOW}No se inicializó el repositorio de Git${NC}"
fi

# Configuración de CI/CD
echo -e "${YELLOW}Configurando CI/CD...${NC}"
if ask_yes_no "¿Deseas configurar GitHub Actions para CI/CD?"; then
    mkdir -p .github/workflows
    cat << EOF > .github/workflows/ci-cd.yml
name: CI/CD

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Set up JDK 11
      uses: actions/setup-java@v2
      with:
        java-version: '11'
        distribution: 'adopt'

    - name: Build backend
      run: |
        cd backend
        ./mvnw clean install

    - name: Build frontend
      run: |
        cd frontend
        npm ci
        npm run build

    - name: Build and push Docker images
      run: |
        docker-compose build
        # Aquí puedes agregar los comandos para subir las imágenes a un registro de Docker
EOF

    echo -e "${GREEN}Configuración de GitHub Actions completada${NC}"
else
    echo -e "${YELLOW}No se configuró CI/CD${NC}"
fi

echo -e "${GREEN}¡Proyecto creado exitosamente!${NC}"
echo -e "Para iniciar el proyecto:"
echo -e "1. cd $PROJECT_NAME"
echo -e "2. docker-compose up --build"


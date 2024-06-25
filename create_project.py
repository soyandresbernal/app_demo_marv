import os
import requests
import zipfile
import subprocess
import json
from pathlib import Path
import getpass

def ask_yes_no(question):
    while True:
        response = input(f"{question} (y/n): ").lower()
        if response in ['y', 'yes']:
            return True
        elif response in ['n', 'no']:
            return False
        else:
            print("Por favor, responde 'y' o 'n'.")

def ask_yes_no(question):
    while True:
        response = input(f"{question} (y/n): ").lower()
        if response in ['y', 'yes']:
            return True
        elif response in ['n', 'no']:
            return False
        else:
            print("Por favor, responde 'y' o 'n'.")

def create_backend():
    print("Configurando el backend con Spring Boot...")
    spring_boot_version = input("Versión de Spring Boot (default 3.2.0): ") or "3.2.0"
    group_id = input("Grupo (com.example): ") or "com.example"
    artifact_id = input("Artefacto (demo): ") or "demo"

    backend_dir = Path("backend")
    backend_dir.mkdir(exist_ok=True)
    os.chdir(backend_dir)

    print("Descargando el proyecto Spring Boot...")
    url = "https://start.spring.io/starter.zip"
    params = {
        "type": "maven-project",
        "language": "java",
        "bootVersion": spring_boot_version,
        "baseDir": ".",
        "groupId": group_id,
        "artifactId": artifact_id,
        "name": artifact_id,
        "description": "Demo project for Spring Boot",
        "packageName": f"{group_id}.{artifact_id}".replace("-", "").replace("_", ""),
        "packaging": "jar",
        "javaVersion": "17",
        "dependencies": "web,data-jpa,h2"
    }

    response = requests.get(url, params=params)
    if response.status_code == 200:
        with open("backend.zip", "wb") as f:
            f.write(response.content)

        print("Descomprimiendo el proyecto...")
        with zipfile.ZipFile("backend.zip", "r") as zip_ref:
            zip_ref.extractall(".")
        os.remove("backend.zip")
        print("Backend creado exitosamente")
    else:
        print(f"Error al descargar el backend. Código de estado: {response.status_code}")
        print("Respuesta del servidor:")
        print(response.text)
        print("Parámetros de la solicitud:")
        print(json.dumps(params, indent=2))
        exit(1)

    os.chdir("..")

def create_frontend():
    print("Configurando el frontend con Vite...")
    if ask_yes_no("¿Deseas usar Nx para el frontend?"):
        subprocess.run(["npx", "create-nx-workspace@latest", "frontend", "--preset=react-standalone"], check=True)
    else:
        subprocess.run(["npm", "init", "vite@latest", "frontend", "--", "--template", "react-ts"], check=True)
        os.chdir("frontend")
        subprocess.run(["npm", "install"], check=True)
        os.chdir("..")
    print("Frontend creado exitosamente")

def configure_docker():
    print("Configurando Docker...")

    # Dockerfile para el backend
    with open("backend/Dockerfile", "w") as f:
        f.write("""FROM openjdk:11-jdk-slim
VOLUME /tmp
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
ENTRYPOINT ["java","-jar","/app.jar"]
""")

    # Dockerfile para el frontend
    with open("frontend/Dockerfile", "w") as f:
        f.write("""FROM node:14
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "run", "start"]
""")

    # docker-compose.yml
    with open("docker-compose.yml", "w") as f:
        f.write("""version: '3'
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
""")

    print("Configuración de Docker completada")

def setup_git_and_github():
    print("Configurando Git y GitHub...")

    # Inicializar repositorio Git
    subprocess.run(["git", "init"], check=True)
    subprocess.run(["git", "add", "."], check=True)
    subprocess.run(["git", "commit", "-m", "Initial commit"], check=True)

    # Configurar GitHub
    github_username = input("Introduce tu nombre de usuario de GitHub: ")
    github_token = getpass.getpass("Introduce tu token de acceso personal de GitHub: ")
    repo_name = input("Introduce el nombre para tu nuevo repositorio en GitHub: ")

    # Crear repositorio en GitHub
    headers = {
        "Authorization": f"token {github_token}",
        "Accept": "application/vnd.github.v3+json"
    }
    data = {
        "name": repo_name,
        "private": False
    }
    response = requests.post("https://api.github.com/user/repos", headers=headers, json=data)

    if response.status_code == 201:
        print(f"Repositorio '{repo_name}' creado exitosamente en GitHub.")
        repo_url = response.json()["ssh_url"]
        subprocess.run(["git", "remote", "add", "origin", repo_url], check=True)
        subprocess.run(["git", "push", "-u", "origin", "main"], check=True)
    else:
        print(f"Error al crear el repositorio en GitHub. Código de estado: {response.status_code}")
        print(response.text)

def setup_ci_cd():
    print("Configurando CI/CD con GitHub Actions...")

    os.makedirs(".github/workflows", exist_ok=True)

    with open(".github/workflows/ci-cd.yml", "w") as f:
        f.write("""name: CI/CD

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Set up JDK 17
      uses: actions/setup-java@v2
      with:
        java-version: '17'
        distribution: 'adopt'

    - name: Build and test backend
      run: |
        cd backend
        ./mvnw clean test

    - name: Set up Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '14'

    - name: Build and test frontend
      run: |
        cd frontend
        npm ci
        npm test
        npm run build

    - name: Build Docker images
      run: docker-compose build
""")

def setup_tests():
    print("Configurando tests...")

    # Backend tests (Spring Boot ya incluye JUnit por defecto)

    # Frontend tests
    os.chdir("frontend")
    with open("src/App.test.js", "w") as f:
        f.write("""import { render, screen } from '@testing-library/react';
import App from './App';

test('renders learn react link', () => {
  render(<App />);
  const linkElement = screen.getByText(/learn react/i);
  expect(linkElement).toBeInTheDocument();
});
""")
    os.chdir("..")

def main():
    create_backend()
    create_frontend()
    configure_docker()
    setup_tests()
    setup_git_and_github()
    setup_ci_cd()
    print("¡Proyecto creado y configurado exitosamente!")
    print("Para iniciar el proyecto:")
    print("1. cd <nombre_del_proyecto>")
    print("2. docker-compose up --build")

if __name__ == "__main__":
    main()
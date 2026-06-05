// Jenkinsfile — CI mirror of the GitHub Actions pipeline (lint / test / build ONLY).
// Deploy is intentionally NOT here: GitHub Actions owns deployment so there is a
// single source of truth for what is live. This file demonstrates declarative
// Jenkins pipeline authoring for on-prem / air-gapped (e.g. defense) environments.

pipeline {
    // No global agent: each stage picks the environment that fits its job.
    // Lint/Test run inside a throwaway Python container; Build runs on the host
    // (which has the Docker daemon) because you can't `docker build` from inside
    // a slim Python container without docker-in-docker.
    agent none

    options {
        timestamps()                       // prefix every log line with a timestamp
        timeout(time: 15, unit: 'MINUTES') // kill a hung run instead of holding an agent forever
    }

    stages {
        stage('Lint') {
            agent { docker { image 'python:3.12-slim' } }
            steps {
                sh 'pip install --no-cache-dir ruff'
                sh 'ruff check app'
            }
        }

        stage('Test') {
            agent { docker { image 'python:3.12-slim' } }
            steps {
                sh 'pip install --no-cache-dir -r app/requirements-dev.txt'
                // `python -m pytest` puts the repo root on sys.path so
                // `from app.main import app` resolves without a pytest.ini.
                sh 'python -m pytest app/tests -v'
            }
        }

        stage('Build') {
            agent any  // host agent — has the Docker daemon
            steps {
                // Build only, no push. BUILD_NUMBER is Jenkins' per-run counter,
                // the local analogue of the immutable :sha tag in Actions.
                sh 'docker build -t deployer:${BUILD_NUMBER} .'
            }
        }
    }

    post {
        success { echo 'CI passed: lint + test + build all green.' }
        failure { echo 'CI failed — check the stage logs above.' }
    }
}

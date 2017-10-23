podTemplate(label: 'sanbase-builder', containers: [
  containerTemplate(name: 'docker', image: 'docker', ttyEnabled: true, command: 'cat')
]) {
  node('sanbase-builder') {
    stage('Run Tests') {
      container('docker') {
        checkout scm

        withCredentials([
          string(
            credentialsId: 'SECRET_KEY_BASE',
            variable: 'SECRET_KEY_BASE'
          ),
          string(
            credentialsId: 'aws_account_id',
            variable: 'aws_account_id'
          ),
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: 'DOCKER_HUB_CREDENTIALS',
            usernameVariable: 'DOCKER_HUB_USERNAME',
            passwordVariable: 'DOCKER_HUB_PASSWORD'
          ]
        ]) {
          sh "docker -H tcp://docker-host-docker-host:2375 build -t sanbase-test:${env.BRANCH_NAME} -f Dockerfile-test ."

          sh "docker -H tcp://docker-host-docker-host:2375 run --name postgres_${env.BRANCH_NAME} -d postgres:9.6-alpine"
          try {
            sh "docker -H tcp://docker-host-docker-host:2375 run --link postgres_${env.BRANCH_NAME}:db --env DATABASE_URL=postgres://postgres:password@db:5432/postgres -t sanbase-test:${env.BRANCH_NAME}"
          } finally {
            sh "docker -H tcp://docker-host-docker-host:2375 kill postgres_${env.BRANCH_NAME}"
          }

          sh "docker -H tcp://docker-host-docker-host:2375 build -t ${env.aws_account_id}.dkr.ecr.eu-central-1.amazonaws.com/sanbase:${env.BRANCH_NAME} --build-arg SECRET_KEY_BASE=${env.SECRET_KEY_BASE} ."

          sh "docker -H tcp://docker-host-docker-host:2375 login -u ${env.DOCKER_HUB_USERNAME} -p ${env.DOCKER_HUB_PASSWORD} https://${env.aws_account_id}.dkr.ecr.eu-central-1.amazonaws.com"

          sh "docker -H tcp://docker-host-docker-host:2375 push ${env.aws_account_id}.dkr.ecr.eu-central-1.amazonaws.com/sanbase:${env.BRANCH_NAME}"
        }
      }
    }
  }
}

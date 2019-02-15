require 'rest-client'
require 'json'
require './lib/gocd'
require './lib/downloader'
require './lib/configuration'
require './lib/plugins'
require './lib/looper'
require 'parallel'

namespace :k8_infra do
  setup = Configuration::SetUp.new
  gocd_server = Configuration::Server.new
  gocd_client = GoCD::Client.new gocd_server.url

  task :prepare_gke_k8s_cluster do

   # sh("gcloud auth activate-service-account #{ENV['K8S_ACCOUNT']} --key-file=#{ENV['K8S_KEYFILE']}")
    sh("gcloud config set project #{ENV['K8S_PROJECT_NAME']}")
    sh("gcloud container clusters create #{ENV['K8S_CLUSTER_NAME']} --num-nodes=#{ENV['K8S_NODES_COUNT']} --zone #{ENV['K8S_REGION']} --machine-type=#{ENV['K8S_MACHINE_TYPE']} --cluster-version=#{ENV['K8S_CLUSTER_VERSION']}")
    sh("gcloud container clusters get-credentials #{ENV['K8S_CLUSTER_NAME']} --zone #{ENV['K8S_REGION']}")

    sh("Kubectl delete clusterrolebinding clusterRoleBinding || true")
    sh("kubectl create clusterrolebinding clusterRoleBinding --clusterrole=cluster-admin --serviceaccount=kube-system:default")

    sh("helm init --wait")
    sh("helm repo add stable https://kubernetes-charts.storage.googleapis.com")
    sh("kubectl create namespace gocd")
  end

  task :delete_gke_k8s_cluster do
    sh("gcloud container clusters get-credentials #{ENV['K8S_CLUSTER_NAME']} --zone #{ENV['K8S_REGION']}")
    sh("gcloud container clusters delete #{ENV['K8S_CLUSTER_NAME']} --quiet --zone #{ENV['K8S_REGION']}")
  end


  task :setup_gocd_server do

    sh("kubectl create secret generic gocd-extensions --from-literal=extensions_user=#{ENV['EXTENSIONS_USER']} --from-literal=extensions_password='#{ENV['EXTENSIONS_PASSWORD']}' --namespace=gocd")
    sh("kubectl create -f helm_chart/gocd-init-configmap.yaml --namespace=gocd")
    sh("helm install --name gocd-app --namespace gocd stable/gocd -f helm_chart/gocd-server-override-values.yaml")

  end

  task :setup_postgresdb do

    sh("helm install --name postgresdb stable/postgresql -f  helm_chart/postgres-values.yaml --set postgresqlDataDir=/bitnami/postgresql/gocd --namespace=gocd")
  end

  task :setup_git_repos do

    sh("kubectl create configmap perf-keys --from-literal number_of_repos=2 --from-literal number_of_config_repos=1 --from-literal number_of_pipelines_in_config_repos=1 --from-literal git_commit_interval=90 --from-literal config_repo_commit_interval=1 --from-literal test_duration=30000 --namespace=gocd")
    sh("kubectl create -f helm_chart/perf-repo-service.yaml --namespace=gocd")
    sh("kubectl create -f helm_chart/gocd-repos-init-configmap.yaml --namespace=gocd")
    sh("kubectl create -f helm_chart/perf-repos-pod.yaml --namespace=gocd")
    
  end

  task :prepare_eks_k8s_cluster do

    sh("eksctl create cluster --ssh-access  --ssh-public-key=#{ENV['ECS_SSH_KEY_NAME']} --name #{ENV['EKS_CLUSTER_NAME']} --nodes #{ENV['EKS_WORKER_NODES']} --region #{ENV['EKS_CLUSTER_REGION']} --verbose 4")
    sh("Kubectl delete clusterrolebinding clusterRoleBinding || true")
    sh("kubectl create clusterrolebinding clusterRoleBinding --clusterrole=cluster-admin --serviceaccount=kube-system:default")
    sh("kubectl create serviceaccount tiller --namespace kube-system")
    sh("kubectl apply -f helm_chart/rbac-config.yaml")
    sh("helm init --service-account tiller --wait")
    sh("helm repo add stable https://kubernetes-charts.storage.googleapis.com")
    sh("kubectl create namespace gocd")

  end

  task :delete_eks_k8s_cluster do

    sh("eksctl delete cluster --name #{ENV['EKS_CLUSTER_NAME']} --region #{ENV['EKS_CLUSTER_REGION']}")

  end

end

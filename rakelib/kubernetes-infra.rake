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

  task :setup_new_relic_license do
    newrelic_config = File.read('resources/newrelic.yml')
    newrelic_config.gsub!(/<%= license_key %>/,"#{ENV['NEWRELIC_LICENSE_KEY']}")
    File.open('resources/newrelic.yml', 'w') do |f|
      f.write newrelic_config
    end
    
  end

  task :setup_gocd_server do

    sh("kubectl create secret generic gocd-extensions --from-literal=extensions_user=#{ENV['EXTENSIONS_USER']} --from-literal=extensions_password='#{ENV['EXTENSIONS_PASSWORD']}' --namespace=gocd")
    sh("kubectl create -f helm_chart/gocd-init-configmap.yaml --namespace=gocd")
    sh("kubectl create configmap gocd-config-files-configmap --from-file=resources --namespace=gocd")
    sh("helm install --name gocd-app --namespace gocd stable/gocd --set server.image.repository=#{ENV['SERVER_IMAGE_REPOSITORY']} --set server.image.tag=#{ENV['SERVER_IMAGE_TAG']} -f helm_chart/gocd-server-override-values.yaml")

  end

  task :expose_gocdserver_lb do

    GO_SERVER_LB=`kubectl get svc gocd-app-server -o=go-template --template='{{(index .status.loadBalancer.ingress 0 ).hostname}}' --namespace=gocd`
    request_to_update_route53={
      "Comment": "changed value for the eks perf run on $time",
          "Changes": [
            {
              "Action": "UPSERT",
              "ResourceRecordSet": {
            "Name": "perf-eks-test.gocd.org.",
            "Type": "CNAME",
            "TTL": 300,
            "ResourceRecords": [
                {
                    "Value": "#{GO_SERVER_LB}"
                }
            ]
              }
        }
      ]
    }.to_json
    
    File.open("helm_chart/batch-change.json", 'w') { |file| file.write(request_to_update_route53) }
    sh("aws route53 change-resource-record-sets --hosted-zone-id Z2I0AUBABYDS9 --change-batch file://helm_chart/batch-change.json")
    
  end

  task :setup_postgresdb do

    sh("helm install --name postgresdb stable/postgresql -f  helm_chart/postgres-values.yaml --set postgresqlDataDir=/bitnami/postgresql/gocd --namespace=gocd --version 3.10.2")
  end

  task :setup_git_repos do

    sh("kubectl create configmap perf-keys --from-literal number_of_pipelines=#{ENV['NO_OF_PIPELINES']} --from-literal no_of_pipelines_in_config_repos=#{ENV['NO_OF_PIPELINES_CONFIG_REPO']} --from-literal performance_repo_directory=#{ENV['PERFORMANCE_REPO_DIRECTORY']} --from-literal git_commit_interval=#{ENV['GIT_COMMIT_INTERVAL']} --from-literal load_test_duration=#{ENV['LOAD_TEST_DURATION']} --from-literal performance_repo_branch=#{ENV['PERF_REPO_BRANCH']} --from-literal perf_repo_url=#{ENV['PERF_REPO_URL']} --from-literal git_root=#{ENV['GIT_ROOT']} --from-literal k8_elastic_agent_profile=#{ENV['K8_ELASTIC_AGENT_PROFILE']} --namespace=gocd")
    sh("kubectl create -f helm_chart/perf-repo-service.yaml --namespace=gocd")
    sh("kubectl create -f helm_chart/gocd-repos-init-configmap.yaml --namespace=gocd")
    sh("kubectl create -f helm_chart/perf-repos-pod.yaml --namespace=gocd")
    
  end

  task :prepare_eks_k8s_cluster do

    sh("eksctl create cluster --ssh-access  --ssh-public-key=#{ENV['ECS_SSH_KEY_NAME']} --name #{ENV['EKS_CLUSTER_NAME']} --nodes #{ENV['EKS_WORKER_NODES']} --node-type=#{ENV['EKS_WORKER_NODE_TYPE']} --region #{ENV['EKS_CLUSTER_REGION']} --max-pods-per-node #{ENV['MAX_PODS_PER_NODE']} --verbose 4")
    sh("Kubectl delete clusterrolebinding clusterRoleBinding || true")
    sh("kubectl create clusterrolebinding clusterRoleBinding --clusterrole=cluster-admin --serviceaccount=kube-system:default")
    sh("kubectl create serviceaccount tiller --namespace kube-system")
    sh("kubectl apply -f helm_chart/rbac-config.yaml")
    sh("helm init --service-account tiller --wait")
    sh("helm repo add stable https://kubernetes-charts.storage.googleapis.com")
    sh("kubectl create namespace gocd")

  end

  task :delete_eks_k8s_cluster do
    
    sh("kubectl delete namespaces gocd")
    sh("helm del --purge postgresdb gocd-app")
    sh("eksctl delete cluster --name #{ENV['EKS_CLUSTER_NAME']} --region #{ENV['EKS_CLUSTER_REGION']}")

  end

end

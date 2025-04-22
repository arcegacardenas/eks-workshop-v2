#!/bin/bash
# Complete solution for EKS Workshop Terraform provider issues on macOS

echo "Starting EKS Workshop Terraform provider fix for macOS..."

# Define the provider versions directly since grep -P doesn't work on macOS
AWS_VERSION="5.90.0"
KUBERNETES_VERSION="2.36.0"
HELM_VERSION="2.17.0"
KUBECTL_VERSION="1.19.0"
LOCAL_VERSION="2.5.2"
NULL_VERSION="3.2.1"
TEMPLATE_VERSION="2.2.0"
RANDOM_VERSION="3.6.0"

echo "Using the following provider versions:"
echo "AWS: $AWS_VERSION"
echo "Kubernetes: $KUBERNETES_VERSION"
echo "Helm: $HELM_VERSION"
echo "Kubectl: $KUBECTL_VERSION"
echo "Local: $LOCAL_VERSION"
echo "Null: $NULL_VERSION"
echo "Template: $TEMPLATE_VERSION"
echo "Random: $RANDOM_VERSION"

# Step 2: Create provider directories
echo "Creating provider directories..."
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/aws/$AWS_VERSION/darwin_arm64/
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/kubernetes/$KUBERNETES_VERSION/darwin_arm64/
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/helm/$HELM_VERSION/darwin_arm64/
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/gavinbunney/kubectl/$KUBECTL_VERSION/darwin_arm64/
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/local/$LOCAL_VERSION/darwin_arm64/
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/null/$NULL_VERSION/darwin_arm64/
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/template/$TEMPLATE_VERSION/darwin_arm64/
mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/random/$RANDOM_VERSION/darwin_arm64/

# Step 3: Create a temporary directory for downloads
echo "Creating temporary download directory..."
mkdir -p ~/terraform-providers-download
cd ~/terraform-providers-download

# Step 4: Download and extract provider binaries
echo "Downloading AWS provider..."
wget https://releases.hashicorp.com/terraform-provider-aws/$AWS_VERSION/terraform-provider-aws_${AWS_VERSION}_darwin_arm64.zip
unzip terraform-provider-aws_${AWS_VERSION}_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.terraform.io/hashicorp/aws/$AWS_VERSION/darwin_arm64/

echo "Downloading Kubernetes provider..."
wget https://releases.hashicorp.com/terraform-provider-kubernetes/$KUBERNETES_VERSION/terraform-provider-kubernetes_${KUBERNETES_VERSION}_darwin_arm64.zip
unzip terraform-provider-kubernetes_${KUBERNETES_VERSION}_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.terraform.io/hashicorp/kubernetes/$KUBERNETES_VERSION/darwin_arm64/

echo "Downloading Helm provider..."
wget https://releases.hashicorp.com/terraform-provider-helm/$HELM_VERSION/terraform-provider-helm_${HELM_VERSION}_darwin_arm64.zip
unzip terraform-provider-helm_${HELM_VERSION}_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.terraform.io/hashicorp/helm/$HELM_VERSION/darwin_arm64/

echo "Downloading Kubectl provider..."
wget https://github.com/gavinbunney/terraform-provider-kubectl/releases/download/v$KUBECTL_VERSION/terraform-provider-kubectl_${KUBECTL_VERSION}_darwin_arm64.zip
unzip terraform-provider-kubectl_${KUBECTL_VERSION}_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.terraform.io/gavinbunney/kubectl/$KUBECTL_VERSION/darwin_arm64/

echo "Downloading Local provider..."
wget https://releases.hashicorp.com/terraform-provider-local/$LOCAL_VERSION/terraform-provider-local_${LOCAL_VERSION}_darwin_arm64.zip
unzip terraform-provider-local_${LOCAL_VERSION}_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.terraform.io/hashicorp/local/$LOCAL_VERSION/darwin_arm64/

echo "Downloading Null provider..."
wget https://releases.hashicorp.com/terraform-provider-null/$NULL_VERSION/terraform-provider-null_${NULL_VERSION}_darwin_arm64.zip
unzip terraform-provider-null_${NULL_VERSION}_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.terraform.io/hashicorp/null/$NULL_VERSION/darwin_arm64/

echo "Downloading Template provider..."
wget https://releases.hashicorp.com/terraform-provider-template/$TEMPLATE_VERSION/terraform-provider-template_${TEMPLATE_VERSION}_darwin_arm64.zip
unzip terraform-provider-template_${TEMPLATE_VERSION}_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.terraform.io/hashicorp/template/$TEMPLATE_VERSION/darwin_arm64/

echo "Downloading Random provider..."
wget https://releases.hashicorp.com/terraform-provider-random/$RANDOM_VERSION/terraform-provider-random_${RANDOM_VERSION}_darwin_arm64.zip
unzip terraform-provider-random_${RANDOM_VERSION}_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.terraform.io/hashicorp/random/$RANDOM_VERSION/darwin_arm64/

# Step 5: Set permissions for the provider binaries
echo "Setting executable permissions..."
find ~/.terraform.d/plugins -type f -name "terraform-provider-*" -exec chmod +x {} \;

# Step 6: Create Terraform configuration file to use local providers
echo "Creating Terraform configuration file..."
cat > ~/.terraformrc << EOF
provider_installation {
  filesystem_mirror {
    path    = "$HOME/.terraform.d/plugins"
    include = ["registry.terraform.io/hashicorp/aws", 
               "registry.terraform.io/hashicorp/kubernetes", 
               "registry.terraform.io/hashicorp/helm", 
               "registry.terraform.io/gavinbunney/kubectl", 
               "registry.terraform.io/hashicorp/local",
               "registry.terraform.io/hashicorp/null",
               "registry.terraform.io/hashicorp/template",
               "registry.terraform.io/hashicorp/random"]
  }
  direct {
    exclude = ["registry.terraform.io/hashicorp/aws", 
               "registry.terraform.io/hashicorp/kubernetes", 
               "registry.terraform.io/hashicorp/helm", 
               "registry.terraform.io/gavinbunney/kubectl", 
               "registry.terraform.io/hashicorp/local",
               "registry.terraform.io/hashicorp/null",
               "registry.terraform.io/hashicorp/template",
               "registry.terraform.io/hashicorp/random"]
  }
}
EOF

# Step 7: Set environment variables to improve connectivity
echo "Setting environment variables..."
export TF_CLI_HTTP_TIMEOUT=300
export TF_REGISTRY_CLIENT_TIMEOUT=300
export HTTP_PROXY=""
export HTTPS_PROXY=""

echo "Script completed. You should now be able to run Terraform commands successfully."
echo "If you're running the EKS workshop locally, you'll need to find the correct path to run the prepare-environment command."

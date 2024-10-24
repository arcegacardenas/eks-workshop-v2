---
title: "ImagePullBackOff - ECR Private Image"
sidebar_position: 42
---

In this section we will learn how to troubleshoot the pod ImagePullBackOff error for a ECR private image.

:::tip Before you start
Prepare your environment for this section:

```bash timeout=600 wait=300
$ prepare-environment troubleshooting/pod/permissions
```

The preparation of the lab might take a couple of minutes and it will make the following changes to your lab environment:

- Create a ECR repo named retail-sample-app-ui.
- Create a EC2 instance and push retail store sample app image in to the ECR repo from the instance using tag 0.4.0 
- Create a new deployment named ui-private in default namespace
- Introduce an issue to the deployment spec, so we can learn how to troubleshoot this type of issues

:::

You can view the Terraform that applies these changes [here](https://github.com/VAR::MANIFESTS_OWNER/VAR::MANIFESTS_REPOSITORY/tree/VAR::MANIFESTS_REF/manifests/modules/troubleshooting/pod/permissions/.workshop/terraform).

Now let's verify if the deployment is created, so we can start troubleshooting the scenario.

```bash
$ kubectl get deploy ui-private -n default
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
ui-private   0/1     1            0           4m25s
```

If you get the same output, it means you are ready to start the troubleshooting.

The task for you in this troubleshooting section is to find the cause for the deployment ui-private to be in 0/1 ready state and to fix it, so that the deployment will have one pod ready and running.

## Let's start the troubleshooting

### Step 1

First, we need to verify the status of our pods.

```bash
$ kubectl get pods
NAME                          READY   STATUS             RESTARTS   AGE
ui-private-7655bf59b9-jprrj   0/1     ImagePullBackOff   0          4m42s
```

### Step 2

You can see that the pod status is showing as ImagePullBackOff. Lets describe the pod to see the events.

```bash
$ POD=`kubectl get pods -o jsonpath='{.items[*].metadata.name}'`
$ kubectl describe pod $POD | awk '/Events:/,/^$/'
Events:
  Type     Reason     Age                    From               Message
  ----     ------     ----                   ----               -------
  Normal   Scheduled  5m15s                  default-scheduler  Successfully assigned default/ui-private-7655bf59b9-jprrj to ip-10-42-33-232.us-west-2.compute.internal
  Normal   Pulling    3m53s (x4 over 5m15s)  kubelet            Pulling image "682844965773.dkr.ecr.us-west-2.amazonaws.com/retail-sample-app-ui:0.4.0"
  Warning  Failed     3m53s (x4 over 5m14s)  kubelet            Failed to pull image "682844965773.dkr.ecr.us-west-2.amazonaws.com/retail-sample-app-ui:0.4.0": failed to pull and unpack image "682844965773.dkr.ecr.us-west-2.amazonaws.com/retail-sample-app-ui:0.4.0": failed to resolve reference "682844965773.dkr.ecr.us-west-2.amazonaws.com/retail-sample-app-ui:0.4.0": unexpected status from HEAD request to https://682844965773.dkr.ecr.us-west-2.amazonaws.com/v2/retail-sample-app-ui/manifests/0.4.0: 403 Forbidden
  Warning  Failed     3m53s (x4 over 5m14s)  kubelet            Error: ErrImagePull
  Warning  Failed     3m27s (x6 over 5m14s)  kubelet            Error: ImagePullBackOff
  Normal   BackOff    4s (x21 over 5m14s)    kubelet            Back-off pulling image "682844965773.dkr.ecr.us-west-2.amazonaws.com/retail-sample-app-ui:0.4.0"
```

### Step 3

From the events of the pod, we can see the 'Failed to pull image' warning, with cause as 403 Forbidden. This gives us an idea that the kubelet faced access denied while trying to pull the image used in the deployment. Lets get the URI of the image used in the deployment.

```bash
$ kubectl get deploy ui-private -o jsonpath='{.spec.template.spec.containers[*].image}'
682844965773.dkr.ecr.us-west-2.amazonaws.com/retail-sample-app-ui:0.4.0
```

### Step 4

From the image URI, we can see that the image is referenced from the account where our EKS cluster is in. Lets check the ECR repository to see if any such image exists.

```bash
$ aws ecr describe-images --repository-name retail-sample-app-ui --image-ids imageTag=0.4.0 
{
    "imageDetails": [
        {
            "registryId": "682844965773",
            "repositoryName": "retail-sample-app-ui",
            "imageDigest": "sha256:b338785abbf5a5d7e0f6ebeb8b8fc66e2ef08c05b2b48e5dfe89d03710eec2c1",
            "imageTags": [
                "0.4.0"
            ],
            "imageSizeInBytes": 268443135,
            "imagePushedAt": "2024-10-11T14:03:01.207000+00:00",
            "imageManifestMediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "artifactMediaType": "application/vnd.docker.container.image.v1+json"
        }
    ]
}
```

You should see that the image path we have in deployment i.e. account_id.dkr.ecr.us-west-2.amazonaws.com/retail-sample-app-ui:0.4.0 have a valid registryId i.e. account-number, valid repositoryName i.e. "retail-sample-app-ui" and valid imageTag i.e. "0.4.0". Which confirms the path of the image is correct and is not a wrong reference. 

:::info
Alternatively, you can also check the console for the same. Click the button below to open the ECR Console. Then click on retail-sample-app-ui repository and the image tag 0.4.0, you should then see the complete URI of the image which should match with the URI in deployment spec i.e. account_id.dkr.ecr.us-west-2.amazonaws.com/retail-sample-app-ui:0.4.0
<ConsoleButton
  url="https://us-west-2.console.aws.amazon.com/ecr/private-registry/repositories?region=us-west-2"
  service="ecr"
  label="Open ECR Console Tab"
/>
:::

### Step 5

As we confirmed that the image URI is correct, lets check the permissions of the kubelet and confirm if the permissions required to pull images from ECR exists. 

Get the IAM role attached to worker nodes in the managed node group of the cluster and list the IAM policies attached to it.

```bash
$ ROLE_NAME=`aws eks describe-nodegroup --cluster-name eks-workshop --nodegroup-name default --query 'nodegroup.nodeRole' --output text | cut -d'/' -f2`
$ aws iam list-attached-role-policies --role-name $ROLE_NAME
{
    "AttachedPolicies": [
        {
            "PolicyName": "AmazonSSMManagedInstanceCore",
            "PolicyArn": "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        },
        {
            "PolicyName": "AmazonEC2ContainerRegistryReadOnly",
            "PolicyArn": "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        },
        {
            "PolicyName": "AmazonEKSWorkerNodePolicy",
            "PolicyArn": "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        },
        {
            "PolicyName": "AmazonSSMPatchAssociation",
            "PolicyArn": "arn:aws:iam::aws:policy/AmazonSSMPatchAssociation"
        }
    ]
}
```

You should see that the AWS managed policy "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" is attached to the worker node role and this policy should provide enough permissions to pull a Image from ECR preivate repository. What else could we check now?

### Step 6

The perimissions to the ECR repository can be managed at both Identity and Resource level. The Identity level permissions are provided at IAM and the resource level permissions are provided at the repository level. As we confirmed that identity based permissions are good, the issue could be with resource level permissions. Lets the check the policy for ECR repo.

```bash
$ aws ecr get-repository-policy --repository-name retail-sample-app-ui
{
    "registryId": "682844965773",
    "repositoryName": "retail-sample-app-ui",
    "policyText": "{\n  \"Version\" : \"2012-10-17\",\n  \"Statement\" : [ {\n    \"Sid\" : \"new policy\",\n    \"Effect\" : \"Deny\",\n    \"Principal\" : {\n      \"AWS\" : \"arn:aws:iam::682844965773:role/eksctl-eks-workshop-nodegroup-defa-NodeInstanceRole-Fa4f8r6uT7UD\"\n    },\n    \"Action\" : [ \"ecr:UploadLayerPart\", \"ecr:SetRepositoryPolicy\", \"ecr:PutImage\", \"ecr:ListImages\", \"ecr:InitiateLayerUpload\", \"ecr:GetRepositoryPolicy\", \"ecr:GetDownloadUrlForLayer\", \"ecr:DescribeRepositories\", \"ecr:DeleteRepositoryPolicy\", \"ecr:DeleteRepository\", \"ecr:CompleteLayerUpload\", \"ecr:BatchGetImage\", \"ecr:BatchDeleteImage\", \"ecr:BatchCheckLayerAvailability\" ]\n  } ]\n}"
}
```

You should see that the ECR repository policy has Effect as Deny and the Principal as the EKS managed node role. Which is restricting the kubelet from pulling images in this repository. Lets change the effect to allow and see if the kubelet is able to pull the image.

```bash
$ aws ecr get-repository-policy --repository-name retail-sample-app-ui --query 'policyText' --output text > ecr-policy.json
$ jq '(.Statement[] | select(.Effect == "Deny")).Effect = "Allow"' ecr-policy.json > updated-ecr-policy.json
$ aws ecr set-repository-policy --repository-name retail-sample-app-ui --policy-text file://updated-ecr-policy.json
$ rm ecr-policy.json updated-ecr-policy.json
```

You can confirm if the ECR repo policy updated successfully, by using the above  get-repository-policy command.

### Step 7

Now, check if the pods are running.

```bash
$ kubectl get pods
NAME                          READY   STATUS    RESTARTS   AGE
ui-private-7655bf59b9-s9pvb   1/1     Running   0          65m
```

That concludes the private ECR ImagePullBackOff troubleshooting section. 

## Wrapping it up

General troubleshooting workflow of the pod with ImagePullBackOff on private image includes:

- Check the pod events for a clue on cause of the issue such as not found, access denied or timeout.
- If not found, ensure that the image exists in the path referenced in the private ECR repositories.
- For access denied, check the permissions on worker node role and the ECR repository policy.
- For timeout on ECR, ensure that the worker node is configured to reach the ECR endpoint.

References:
- https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_on_EKS.html
- https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-policies.html
- https://docs.aws.amazon.com/eks/latest/userguide/eks-networking.html

# AWS EC2 Container Services Demo

This repo is the example code for an PHP Laravel application.

## Prerequisites:

To have an Amazon AWS account
* install the AWS CLI; follow instructions in [Amazon documentation](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)
* Configure AWS CLI by providing secret key and Secret Access Key, [Amazon documentation](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
Install docker [https://docs.docker.com/engine/installation/](https://docs.docker.com/engine/installation/)

Have an existing EC2 keypair, if don't you have one, follow the [Amazon instructions](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair)
 
## How to Setup

Just follow the commands displayed bellow to have the repo and docker image ready on your machine

```bash
git clone https://github.com/pjuarezd/containerServices.git
cd containerService
docker build -t ecs-service .
```

After that go to [CloudFormation amazon console](https://us-west-2.console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks?filter=active)

Click on create an stack

Select file stack.yml and click nexy

Provide parameters ins screen (Stackname and keypair)

Accept the AWS Cloudformation Acknowledge and click "Create"
>> Note, Keypair should be an existing keypar in your aws account, if don't you have one create it befor execute cloudformation stack

Amazon will take some time to create the stack of services, give it aroud 10 to 15 minutes, after that proceed to upload the Dodcker image in  ECS following the commands below.

```bash
aws ecr get-login > login.sh

#If you are on linux/mac execute this

bash login.sh
rm login.sh

#If you are in windows, copy the content of login.sh file into a cmd or powershell console and execute it 

docker tag ecs-service:latest {accountid}.dkr.ecr.us-west-2.amazonaws.com/ecs-service:latest
docker push {accountid}.dkr.ecr.us-west-2.amazonaws.com/ecs-service
```
Then the service will be published, 

Go to the [ECS console](https://us-west-2.console.aws.amazon.com/ecs/home?region=us-west-2#/clusters)

Open the cluster "service-cluster"

Open service  "ecs-service"

Inside will be a single task, open it in the guid URL

Under the "Containers" section a container named "ecs-service" will be listed, expand it in the left arrow and look for the property "External link"

That is the IP and port where the servie is running, you can access it on the browser and see the Laravel application Runing

# Files Description

Here i will give a brief description of strategic files in the repo.


## Dockerfile
Dockerfile file contains instructions to install OS dependencies in the Docker container

## startup.sh
Startup.sh is an Shell script with instructions to start the execution of the Nginx and php-fpm services into the container


## Stack.yml
CloudFormation template, contains the details of the ECS Services, describes all the small pieces required to deploy the Containers in a service.

### Template parameters
** KeyPair **
Is the name of the keypair that can be used to connect to the EC2 instances that belong to the cluster

### Outputs:
** EcsCluster **
ECS Cluster ARN, just for reference

# Template Details

### ECR Repository

ECR Repository is the place where the Docker images are storaged, instead of using dockerhub this project expects to have the repo in AWS Services

```yaml
 ServiceRepository: 
    Type: "AWS::ECR::Repository"
    Properties: 
      RepositoryName: "ecs-service"

```

### Task Definition

Task definition is the recipe of how the services or tasks are about to run in the cluster

```yaml
ServiceTaskDefinition: 
    Type: "AWS::ECS::TaskDefinition"
    Properties:
      ContainerDefinitions:
        - Name: "ecs-service"
          Image: { "Fn::Join": ["",[ { "Ref": "AWS::AccountId" }, ".dkr.ecr.us-west-2.amazonaws.com/ecs-service:latest" ] ] } 
          Memory: 600
          MemoryReservation : 160
          PortMappings:
            - ContainerPort: 80
              HostPort: 80
```

### Cluster

Here are the elements required to create the cluster.

A cluster is a set o EC2 Machines that work together to run docker services.

Autoscaling group defines how much EC2 instances are be running and if the amoun increases or decreases over some events (Scaling policies)

AutoScalingLaunchConfiguration are the characteristics of the EC2 VM that will be created, like AMI image, instance type, hard drive size, and so on.

EC2DevInstanceProfile & EC2DevInstanceRole are the grant configurations that will allow handle EC2 resources to the CLuster (Create, destroy, asociate, etc)


```yaml
AutoScalingGroup:
    Type: "AWS::AutoScaling::AutoScalingGroup"
    Properties:
      AvailabilityZones: 
        Fn::GetAZs: ""
      LaunchConfigurationName: { "Ref": "AutoScalingLaunchConfiguration" }
      MinSize: 0
      MaxSize: 3
      DesiredCapacity: 1
  AutoScalingLaunchConfiguration:
    Type: "AWS::AutoScaling::LaunchConfiguration"
    Properties:
      ImageId: "ami-8e7bc4ee"
      InstanceType: t2.micro
      KeyName: { "Ref": "KeyPair" }
      IamInstanceProfile: { "Ref": "EC2DevInstanceProfile" }
      SecurityGroups:
        - { "Ref": "FrontEndSecurityGroup" }
      UserData: {
        "Fn::Base64": { "Fn::Join": ["", [
          "#!/bin/bash\n",
          "echo ECS_CLUSTER=", { "Ref" : "EcsCluster" }, " >> /etc/ecs/ecs.config\n"
        ] ] }
      }
      BlockDeviceMappings:
        -
          DeviceName: "/dev/xvdcz"
          Ebs:
             VolumeSize: 22
             VolumeType: "gp2"
  EC2DevInstanceProfile:
    Type: "AWS::IAM::InstanceProfile"
    Properties: 
      Path: "/"
      Roles: [ { "Ref": "EC2DevInstanceRole" } ]
  EC2DevInstanceRole:
    Type: "AWS::IAM::Role"
    Properties:
      AssumeRolePolicyDocument: {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": { "Service": [ "ec2.amazonaws.com" ] },
            "Action": [ "sts:AssumeRole" ]
          }
        ]
      }
      Path: "/"
      ManagedPolicyArns: 
        - "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  EcsCluster:
    Type: "AWS::ECS::Cluster"
    Properties:
      ClusterName: "service-cluster"

```

### Service
The Service is the container running, this is created using the "template" so called TaskDefinition, and will be running in a designed cluster

```yaml
 ecsService:
    Type: "AWS::ECS::Service"
    Properties:
      TaskDefinition: { "Ref": "ServiceTaskDefinition" }
      Cluster: { "Ref": "EcsCluster" }
      DesiredCount: 1
    DependsOn: [ AutoScalingGroup, EcsCluster]
```

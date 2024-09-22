provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

resource "aws_subnet" "private" {
  count = 3
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = element(["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"], count.index)
  availability_zone = element(["us-east-1a", "us-east-1b", "us-east-1c"], count.index)

  tags = {
    Name = "eks-private-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "public" {
  count = 3
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = element(["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"], count.index)
  availability_zone = element(["us-east-1a", "us-east-1b", "us-east-1c"], count.index)

  tags = {
    Name = "eks-public-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "eks-public-route-table"
  }
}

resource "aws_route_table_association" "public_association" {
  count = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "eks-nat-gateway"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"  
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "eks-private-route-table"
  }
}

resource "aws_route_table_association" "private_association" {
  count = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  version  = "1.30"
  role_arn = data.aws_iam_role.lab_role.arn 
  vpc_config {
    subnet_ids = aws_subnet.private[*].id
  }

  tags = {
    Name = "EKS Fast food"
  }
}


resource "aws_eks_node_group" "node_group" {
  count = 2
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "node-group-${count.index + 1}"
  node_role_arn = data.aws_iam_role.lab_role.arn
  subnet_ids = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.small"]

  tags = {
    Name = "node-group-${count.index + 1}"
  }
}
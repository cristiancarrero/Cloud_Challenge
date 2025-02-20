#!/bin/bash

# 1. CONFIGURACIÓN INICIAL
# -----------------------
# Configurar credenciales AWS
aws configure set aws_access_key_id TU_ACCESS_KEY
aws configure set aws_secret_access_key TU_SECRET_KEY
aws configure set aws_session_token TU_SESSION_TOKEN
aws configure set region us-west-2
aws configure set output json

# Verificar configuración
aws s3 ls

# 2. CREAR ESTRUCTURA DEL PROYECTO
# -------------------------------
mkdir -p cloud_challenge/assets/img
cd cloud_challenge
touch index.html styles.css script.js

# 3. RETO 1 - WEB ESTÁTICA EN S3
# -----------------------------
# Crear y configurar bucket
BUCKET_NAME="cloud-challenge-team-$(date +%Y%m%d)"
aws s3 mb s3://$BUCKET_NAME
aws s3 website s3://$BUCKET_NAME --index-document index.html

# Subir archivos
aws s3 sync . s3://$BUCKET_NAME \
    --exclude ".git/*" \
    --exclude "comandos.sh" \
    --acl public-read

# Configurar política del bucket
aws s3api put-bucket-policy \
    --bucket $BUCKET_NAME \
    --policy '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "PublicReadGetObject",
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*"
            }
        ]
    }'

# Verificar configuración
aws s3api get-bucket-website --bucket $BUCKET_NAME
aws s3 ls s3://$BUCKET_NAME
aws s3api get-public-access-block --bucket $BUCKET_NAME
echo "URL del sitio: http://$BUCKET_NAME.s3-website-us-west-2.amazonaws.com"

# 4. RETO 2 - URL PREFIRMADA
# -------------------------
# Crear segundo bucket
IMG_BUCKET="cloud-challenge-images-$(date +%Y%m%d)"
aws s3 mb s3://$IMG_BUCKET

# Subir imagen y crear URL prefirmada
aws s3 cp ./vision-aws.jpg s3://$IMG_BUCKET/vision-aws.jpg
aws s3 presign s3://$IMG_BUCKET/vision-aws.jpg --expires-in 180

# 5. RETO 3 - EC2 CON ELB
# ----------------------
# Crear grupo de seguridad
aws ec2 create-security-group \
    --group-name web-sg \
    --description "Security group for web servers"

aws ec2 authorize-security-group-ingress \
    --group-name web-sg \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Crear 3 instancias EC2
for i in {1..3}; do
    aws ec2 run-instances \
        --image-id ami-0735c191cf914754d \
        --instance-type t2.micro \
        --security-groups web-sg \
        --user-data '#!/bin/bash
            yum update -y
            yum install -y httpd
            systemctl start httpd
            systemctl enable httpd
            echo "<div>EC2 response: $(hostname -f)</div>" >> /var/www/html/index.html' \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=web-server-$i}]"
done

# Crear y configurar ELB (reemplazar XXX con valores reales)
aws elbv2 create-load-balancer \
    --name web-lb \
    --subnets subnet-xxx subnet-yyy \
    --security-groups sg-xxx

aws elbv2 create-target-group \
    --name web-targets \
    --protocol HTTP \
    --port 80 \
    --vpc-id vpc-xxx

# 6. RETO 4 - CLOUDTRAIL
# ---------------------
# Verificar eventos
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=PutObject
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=CreateLoadBalancer

# 7. LIMPIEZA (cuando sea necesario)
# --------------------------------
# Limpiar S3
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rm s3://$IMG_BUCKET --recursive
aws s3 rb s3://$BUCKET_NAME
aws s3 rb s3://$IMG_BUCKET

# Limpiar EC2 y ELB (reemplazar XXX con IDs reales)
aws ec2 terminate-instances --instance-ids i-xxx i-yyy i-zzz
aws elbv2 delete-load-balancer --load-balancer-arn arn:xxx
aws elbv2 delete-target-group --target-group-arn arn:xxx
aws ec2 delete-security-group --group-name web-sg 
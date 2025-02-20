#!/bin/bash

# Variables
BUCKET_NAME="cloud-challenge-team-20250220"
REGION="us-west-2"

# Crear el bucket si no existe
echo "🪣 Verificando/Creando bucket S3..."
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION

# Desactivar el bloqueo de acceso público
echo "🔓 Desactivando bloqueo de acceso público..."
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# Configurar el bucket para hosting web estático
echo "🌐 Configurando bucket para web hosting..."
aws s3 website s3://$BUCKET_NAME \
    --index-document index.html \
    --error-document index.html

# Crear política de bucket
echo "🔒 Configurando política del bucket..."
cat > bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        }
    ]
}
EOF

# Aplicar la política
aws s3api put-bucket-policy \
    --bucket $BUCKET_NAME \
    --policy file://bucket-policy.json

# Subir archivos
echo "📤 Subiendo archivos al bucket..."
aws s3 cp index.html s3://$BUCKET_NAME/
aws s3 cp styles.css s3://$BUCKET_NAME/
aws s3 cp script.js s3://$BUCKET_NAME/
aws s3 sync assets/ s3://$BUCKET_NAME/assets/

# Limpiar archivos temporales
rm bucket-policy.json

# Mostrar URL
echo "✅ Despliegue completado!"
echo "🌎 Tu sitio está disponible en:"
echo "http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com" 
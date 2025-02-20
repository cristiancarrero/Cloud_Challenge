#!/bin/bash

# Variables
BUCKET_NAME="cloud-challenge-web-static"
REGION="us-west-2"

# Construir la aplicación
echo "🏗️ Construyendo la aplicación..."
npm run build

# Crear el bucket si no existe
echo "🪣 Verificando/Creando bucket S3..."
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION

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
aws s3 sync dist/ s3://$BUCKET_NAME \
    --delete \
    --cache-control "max-age=3600"

# Limpiar archivos temporales
rm bucket-policy.json

# Mostrar URL
echo "✅ Despliegue completado!"
echo "🌎 Tu sitio está disponible en:"
echo "http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com" 
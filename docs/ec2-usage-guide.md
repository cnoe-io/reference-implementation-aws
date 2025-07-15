# Guía de uso: Instancias EC2 en CNOE AWS

Esta guía describe cómo crear y gestionar instancias EC2 en AWS utilizando el Internal Developer Platform basado en CNOE.

## Requisitos previos

- Acceso al clúster de Kubernetes donde se ha desplegado CNOE
- Conocimiento básico de AWS y EC2
- Permisos necesarios para crear recursos en el namespace designado

## Creación de una instancia EC2

Para crear una instancia EC2, es necesario crear un archivo YAML con el recurso `EC2Instance`. A continuación se muestra un ejemplo:

```yaml
apiVersion: aws.cnoe.io/v1alpha1
kind: EC2Instance
metadata:
  name: mi-instancia
  namespace: tu-namespace
spec:
  instanceName: nombre-instancia-ec2
  instanceType: t2.micro
  ami: ami-0c55b159cbfafe1f0  # Amazon Linux 2 AMI (ajustar según la región)
  subnet: subnet-12345678  # Reemplazar con el ID de subnet real
  securityGroup: sg-12345678  # Reemplazar con el ID de security group real
  keyName: nombre-clave-ssh  # Reemplazar con el nombre de clave SSH
  tags:
    Environment: desarrollo
    Project: mi-proyecto
  compositionRef:
    name: xec2instances.aws.cnoe.io
  writeConnectionSecretToRef:
    name: mi-instancia-ec2-details
    namespace: tu-namespace
```

### Parámetros importantes

| Parámetro | Descripción | Obligatorio |
|-----------|-------------|-------------|
| instanceName | Nombre para la instancia EC2 | Sí |
| instanceType | Tipo de instancia EC2 (t2.micro, t3.small, etc.) | No (por defecto: t2.micro) |
| ami | ID de la Amazon Machine Image (AMI) | No (por defecto: Amazon Linux 2) |
| subnet | ID de la subred VPC | Sí |
| securityGroup | ID del grupo de seguridad | No |
| keyName | Nombre del par de claves SSH | No |
| tags | Etiquetas para aplicar a la instancia | No |

## Despliegue de la instancia EC2

Una vez creado el archivo YAML, puedes desplegar la instancia utilizando kubectl:

```bash
kubectl apply -f mi-instancia-ec2.yaml
```

## Verificación del estado

Para verificar el estado de tu instancia EC2:

```bash
kubectl get ec2instances -n tu-namespace
```

Para obtener información detallada:

```bash
kubectl describe ec2instance mi-instancia -n tu-namespace
```

## Acceso a la información de conexión

Los detalles de conexión se almacenarán en el secreto especificado en `writeConnectionSecretToRef`:

```bash
kubectl get secret mi-instancia-ec2-details -n tu-namespace -o yaml
```

## Eliminación de la instancia

Para eliminar la instancia EC2:

```bash
kubectl delete ec2instance mi-instancia -n tu-namespace
```

## Resolución de problemas

Si encuentras problemas al crear o gestionar instancias EC2, comprueba:

1. Los logs de los controladores Crossplane
2. El estado del recurso personalizado
3. Asegúrate de que Crossplane tiene los permisos IAM necesarios para crear instancias EC2

```bash
kubectl logs -n crossplane-system -l app=crossplane
```

## Limitaciones

- Las instancias EC2 se crean en la región especificada en la composición (por defecto: us-west-2)
- Se requiere una subnet existente para desplegar la instancia
- La eliminación de la instancia EC2 puede tardar algunos minutos en reflejarse en AWS

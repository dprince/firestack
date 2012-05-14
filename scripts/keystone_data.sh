#!/bin/bash
# Tenants
export SERVICE_TOKEN=$SERVICE_TOKEN
export SERVICE_ENDPOINT=$SERVICE_ENDPOINT
export AUTH_ENDPOINT=$AUTH_ENDPOINT

function get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

ADMIN_PASSWORD="AABBCC112233"
SERVICE_PASSWORD="SERVICE_PASSWORD"
ADMIN_TENANT=`get_id keystone tenant-create --name=admin`
SERVICE_TENANT=$(get_id keystone tenant-create --name=service)
DEMO_TENANT=`get_id keystone tenant-create --name=demo`
INVIS_TENANT=`get_id keystone tenant-create --name=invisible_to_admin`

# Users
ADMIN_USER=`get_id keystone user-create \
                                 --name=admin \
                                 --pass="$ADMIN_PASSWORD" \
                                 --email=admin@example.com`
DEMO_USER=`get_id keystone user-create \
                                 --name=demo \
                                 --pass="DDEEFF445566" \
                                 --email=admin@example.com`

# Roles
ADMIN_ROLE=`get_id keystone role-create --name=admin`
MEMBER_ROLE=`get_id keystone role-create --name=Member`
KEYSTONEADMIN_ROLE=`get_id keystone role-create --name=KeystoneAdmin`
KEYSTONESERVICE_ROLE=`get_id keystone role-create --name=KeystoneServiceAdmin`
SYSADMIN_ROLE=`get_id keystone role-create --name=sysadmin`
NETADMIN_ROLE=`get_id keystone role-create --name=netadmin`


# Add Roles to Users in Tenants

keystone user-role-add --user="$ADMIN_USER" \
                       --role="$ADMIN_ROLE" \
                       --tenant_id="$ADMIN_TENANT"
keystone user-role-add --user="$DEMO_USER" \
                       --role="$MEMBER_ROLE" \
                       --tenant_id="$DEMO_TENANT"
keystone user-role-add --user="$DEMO_USER" \
                       --role="$SYSADMIN_ROLE" \
                       --tenant_id="$DEMO_TENANT"
keystone user-role-add --user="$DEMO_USER" \
                       --role="$NETADMIN_ROLE" \
                       --tenant_id="$DEMO_TENANT"
keystone user-role-add --user="$DEMO_USER" \
                       --role="$MEMBER_ROLE" \
                       --tenant_id="$INVIS_TENANT"
keystone user-role-add --user="$ADMIN_USER" \
                       --role="$ADMIN_ROLE" \
                       --tenant_id="$DEMO_TENANT"

keystone user-role-add --user="$ADMIN_USER" \
                       --role="$KEYSTONEADMIN_ROLE" \
                       --tenant_id="$ADMIN_TENANT"
keystone user-role-add --user="$ADMIN_USER" \
                       --role="$KEYSTONESERVICE_ROLE" \
                       --tenant_id="$ADMIN_TENANT"

# Nova Service
keystone service-create \
                                 --name=nova \
                                 --type=compute \
                                 --description="Nova Compute Service"
NOVA_USER=`get_id keystone user-create \
                                 --name=nova \
                                 --pass="$SERVICE_PASSWORD" \
                                 --email=nova@example.com`
keystone user-role-add --tenant_id $SERVICE_TENANT \
                       --user $NOVA_USER \
                       --role $ADMIN_ROLE

# EC2 Service (no user required)
keystone service-create \
                                 --name=ec2 \
                                 --type=ec2 \
                                 --description="EC2 Compatibility Layer"

# Glance Service
keystone service-create \
                                 --name=glance \
                                 --type=image \
                                 --description="Glance Image Service"
GLANCE_USER=`get_id keystone user-create \
                                 --name=glance \
                                 --pass="$SERVICE_PASSWORD" \
                                 --email=glance@example.com`
keystone user-role-add --tenant_id $SERVICE_TENANT \
                       --user $GLANCE_USER \
                       --role $ADMIN_ROLE

# Keystone Service
keystone service-create \
                                 --name=keystone \
                                 --type=identity \
                                 --description="Keystone Identity Service"
if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
    keystone service-create \
                                 --name=swift \
                                 --type="object-store" \
                                 --description="Swift Service"
    SWIFT_USER=`get_id keystone user-create \
                                 --name=swift \
                                 --pass="$SERVICE_PASSWORD" \
                                 --email=swift@example.com`
    keystone user-role-add --tenant_id $SERVICE_TENANT \
                                 --user $SWIFT_USER \
                                 --role $ADMIN_ROLE

fi

# create ec2 creds and parse the secret and access key returned
RESULT=`keystone ec2-credentials-create --tenant_id=$ADMIN_TENANT --user=$ADMIN_USER`
    echo `$@ | grep id | awk '{print $4}'`
ADMIN_ACCESS=`echo "$RESULT" | grep access | awk '{print $4}'`
ADMIN_SECRET=`echo "$RESULT" | grep secret | awk '{print $4}'`


RESULT=`keystone ec2-credentials-create --tenant_id=$DEMO_TENANT --user=$DEMO_USER`
DEMO_ACCESS=`echo "$RESULT" | grep access | awk '{print $4}'`
DEMO_SECRET=`echo "$RESULT" | grep secret | awk '{print $4}'`

cat > /root/openstackrc <<EOF
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASSWORD
export OS_TENANT_NAME=admin
export OS_AUTH_URL=$AUTH_ENDPOINT
export OS_AUTH_STRATEGY=keystone

# legacy options for novaclient
export NOVA_API_KEY="\$OS_PASSWORD"
export NOVA_USERNAME="\$OS_USERNAME"
export NOVA_PROJECT_ID="\$OS_TENANT_NAME"
export NOVA_URL="\$OS_AUTH_URL"
export NOVA_VERSION="1.1"
export EC2_ACCESS_KEY=$ADMIN_ACCESS
export EC2_SECRET_KEY=$ADMIN_SECRET

# Set the ec2 url so euca2ools works
export EC2_URL=\$(keystone catalog --service ec2 | awk '/ publicURL / { print \$4 }')

NOVA_KEY_DIR=\${NOVA_KEY_DIR:-\$HOME}
export S3_URL=\$(keystone catalog --service s3 | awk '/ publicURL / { print \$4 }')
export EC2_USER_ID=42 # nova does not use user id, but bundling requires it
export EC2_PRIVATE_KEY=\${NOVA_KEY_DIR}/pk.pem
export EC2_CERT=\${NOVA_KEY_DIR}/cert.pem
export NOVA_CERT=\${NOVA_KEY_DIR}/cacert.pem
export EUCALYPTUS_CERT=\${NOVA_CERT} # euca-bundle-image seems to require this set
alias ec2-bundle-image="ec2-bundle-image --cert \${EC2_CERT} --privatekey \${EC2_PRIVATE_KEY} --user \${EC2_USER_ID} --ec2cert \${NOVA_CERT}"
alias ec2-upload-bundle="ec2-upload-bundle -a \${EC2_ACCESS_KEY} -s \${EC2_SECRET_KEY} --url \${S3_URL} --ec2cert \${NOVA_CERT}"
EOF

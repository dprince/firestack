#!/bin/bash
# Tenants
export GLANCE_HOST=${GLANCE_HOST:-"localhost"}
export NOVA_HOST=${NOVA_HOST:-"localhost"}
export KEYSTONE_HOST=${KEYSTONE_HOST:-"localhost"}
export SWIFT_HOST=${SWIFT_HOST:-"localhost"}
export CINDER_HOST=${CINDER_HOST:-"localhost"}
export QUANTUM_HOST=${QUANTUM_HOST:-"localhost"}

export SERVICE_TOKEN=$SERVICE_TOKEN
export SERVICE_ENDPOINT=$SERVICE_ENDPOINT
export AUTH_ENDPOINT=$AUTH_ENDPOINT
export OS_NO_CACHE=1

function get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

ADMIN_PASSWORD="AABBCC112233"
USER1_PASSWORD="DDEEFF445566"
USER2_PASSWORD="GGHHII778899"
SERVICE_PASSWORD="SERVICE_PASSWORD"
ADMIN_TENANT=`get_id keystone tenant-create --name=admin`
SERVICE_TENANT=$(get_id keystone tenant-create --name=service)
USER1_TENANT=`get_id keystone tenant-create --name=user1`
USER2_TENANT=`get_id keystone tenant-create --name=user2`
INVIS_TENANT=`get_id keystone tenant-create --name=invisible_to_admin`

# Users
ADMIN_USER=`get_id keystone user-create \
                                 --name=admin \
                                 --pass="$ADMIN_PASSWORD" \
                                 --email=admin@example.com`
USER1_USER=`get_id keystone user-create \
                                 --name=user1 \
                                 --pass="$USER1_PASSWORD" \
                                 --email=user1@example.com`
USER2_USER=`get_id keystone user-create \
                                 --name=user2 \
                                 --pass="GGHHII778899" \
                                 --pass="$USER2_PASSWORD" \
                                 --email=user2@example.com`

# Roles
ADMIN_ROLE=`get_id keystone role-create --name=admin`
MEMBER_ROLE=`get_id keystone role-create --name=Member`
KEYSTONEADMIN_ROLE=`get_id keystone role-create --name=KeystoneAdmin`
KEYSTONESERVICE_ROLE=`get_id keystone role-create --name=KeystoneServiceAdmin`
SYSADMIN_ROLE=`get_id keystone role-create --name=sysadmin`
NETADMIN_ROLE=`get_id keystone role-create --name=netadmin`


# Add Roles to Users in Tenants

keystone user-role-add --user_id="$ADMIN_USER" \
                       --role_id="$ADMIN_ROLE" \
                       --tenant_id="$ADMIN_TENANT"

#user1
keystone user-role-add --user_id="$USER1_USER" \
                       --role_id="$MEMBER_ROLE" \
                       --tenant_id="$USER1_TENANT"
keystone user-role-add --user_id="$USER1_USER" \
                       --role_id="$SYSADMIN_ROLE" \
                       --tenant_id="$USER1_TENANT"
keystone user-role-add --user_id="$USER1_USER" \
                       --role_id="$NETADMIN_ROLE" \
                       --tenant_id="$USER1_TENANT"
keystone user-role-add --user_id="$USER1_USER" \
                       --role_id="$MEMBER_ROLE" \
                       --tenant_id="$INVIS_TENANT"
keystone user-role-add --user_id="$ADMIN_USER" \
                       --role_id="$ADMIN_ROLE" \
                       --tenant_id="$USER1_TENANT"

#user2
keystone user-role-add --user_id="$USER2_USER" \
                       --role_id="$MEMBER_ROLE" \
                       --tenant_id="$USER2_TENANT"
keystone user-role-add --user_id="$USER2_USER" \
                       --role_id="$SYSADMIN_ROLE" \
                       --tenant_id="$USER2_TENANT"
keystone user-role-add --user_id="$USER2_USER" \
                       --role_id="$NETADMIN_ROLE" \
                       --tenant_id="$USER2_TENANT"
keystone user-role-add --user_id="$USER2_USER" \
                       --role_id="$MEMBER_ROLE" \
                       --tenant_id="$INVIS_TENANT"
keystone user-role-add --user_id="$ADMIN_USER" \
                       --role_id="$ADMIN_ROLE" \
                       --tenant_id="$USER2_TENANT"

#keystone admin
keystone user-role-add --user_id="$ADMIN_USER" \
                       --role_id="$KEYSTONEADMIN_ROLE" \
                       --tenant_id="$ADMIN_TENANT"
keystone user-role-add --user_id="$ADMIN_USER" \
                       --role_id="$KEYSTONESERVICE_ROLE" \
                       --tenant_id="$ADMIN_TENANT"

NOVA_USER=`get_id keystone user-create \
                                 --name=nova \
                                 --pass="$SERVICE_PASSWORD" \
                                 --email=nova@example.com`
keystone user-role-add --tenant_id $SERVICE_TENANT \
                       --user_id $NOVA_USER \
                       --role_id $ADMIN_ROLE

NOVA_SERVICE=$(get_id keystone service-create \
            --name=nova \
            --type=compute \
            --description="Compute")
keystone endpoint-create \
            --region RegionOne \
            --service_id $NOVA_SERVICE \
            --publicurl "http://$NOVA_HOST:8774/v2/\$(tenant_id)s" \
            --adminurl "http://$NOVA_HOST:8774/v2/\$(tenant_id)s" \
            --internalurl "http://$NOVA_HOST:8774/v2/\$(tenant_id)s"


# EC2 Service (no user required)
NOVA_EC2_SERVICE=$(get_id keystone service-create \
            --name=ec2 \
            --type=ec2 \
            --description="EC2")
keystone endpoint-create \
            --region RegionOne \
            --service_id $NOVA_EC2_SERVICE \
            --publicurl "http://$NOVA_HOST:8773/services/Cloud" \
            --adminurl "http://$NOVA_HOST:8773/services/Admin" \
            --internalurl "http://$NOVA_HOST:8773/services/Cloud"


# Glance Service
GLANCE_USER=`get_id keystone user-create \
                                 --name=glance \
                                 --pass="$SERVICE_PASSWORD" \
                                 --email=glance@example.com`
keystone user-role-add --tenant_id $SERVICE_TENANT \
                       --user_id $GLANCE_USER \
                       --role_id $ADMIN_ROLE

GLANCE_SERVICE=$(get_id keystone service-create \
            --name=glance \
            --type=image \
            --description="Image")
keystone endpoint-create \
            --region RegionOne \
            --service_id $GLANCE_SERVICE \
            --publicurl "http://$GLANCE_HOST:9292" \
            --adminurl "http://$GLANCE_HOST:9292" \
            --internalurl "http://$GLANCE_HOST:9292"

# Cinder Service
CINDER_USER=`get_id keystone user-create \
                                 --name=cinder \
                                 --pass="$SERVICE_PASSWORD" \
                                 --email=cinder@example.com`
keystone user-role-add --tenant_id $SERVICE_TENANT \
                       --user_id $CINDER_USER \
                       --role_id $ADMIN_ROLE
CINDER_SERVICE=$(get_id keystone service-create \
            --name=cinder \
            --type=volume \
            --description="Volume")
keystone endpoint-create \
            --region RegionOne \
            --service_id $CINDER_SERVICE \
            --publicurl "http://$CINDER_HOST:8776/v1/\$(tenant_id)s" \
            --adminurl "http://$CINDER_HOST:8776/v1/\$(tenant_id)s" \
            --internalurl "http://$CINDER_HOST:8776/v1/\$(tenant_id)s"


# Quantum Service
QUANTUM_USER=`get_id keystone user-create \
                                 --name=quantum \
                                 --pass="$SERVICE_PASSWORD" \
                                 --email=quantum@example.com`
keystone user-role-add --tenant_id $SERVICE_TENANT \
                       --user_id $QUANTUM_USER \
                       --role_id $ADMIN_ROLE

QUANTUM_SERVICE=$(get_id keystone service-create \
            --name=network \
            --type=network \
            --description="Network")
keystone endpoint-create \
            --region RegionOne \
            --service_id $QUANTUM_SERVICE \
            --publicurl "http://$QUANTUM_HOST:9696" \
            --adminurl "http://$QUANTUM_HOST:9696" \
            --internalurl "http://$QUANTUM_HOST:9696"

# Keystone Service
KEYSTONE_SERVICE=$(get_id keystone service-create \
            --name=keystone \
            --type=identity \
            --description="Identity")
keystone endpoint-create \
            --region RegionOne \
            --service_id $KEYSTONE_SERVICE \
            --publicurl "http://$KEYSTONE_HOST:5000" \
            --adminurl "http://$KEYSTONE_HOST:35357" \
            --internalurl "http://$KEYSTONE_HOST:35357"

# Swift Service
SWIFT_USER=`get_id keystone user-create \
                             --name=swift \
                             --pass="$SERVICE_PASSWORD" \
                             --email=swift@example.com`
keystone user-role-add --tenant_id $SERVICE_TENANT \
                             --user_id $SWIFT_USER \
                             --role_id $ADMIN_ROLE

SWIFT_SERVICE=$(get_id keystone service-create \
            --name=swift \
            --type=object-store \
            --description="Object")
keystone endpoint-create \
            --region RegionOne \
            --service_id $SWIFT_SERVICE \
            --publicurl "http://$SWIFT_HOST:8080/v1/AUTH_\$(tenant_id)s" \
            --adminurl "http://$SWIFT_HOST:8080/" \
            --internalurl "http://$SWIFT_HOST:8080/v1/AUTH_\$(tenant_id)s"

# create ec2 creds and parse the secret and access key returned
RESULT=`keystone ec2-credentials-create --tenant_id=$ADMIN_TENANT --user_id=$ADMIN_USER`
    echo `$@ | grep id | awk '{print $4}'`
ADMIN_ACCESS=`echo "$RESULT" | grep access | awk '{print $4}'`
ADMIN_SECRET=`echo "$RESULT" | grep secret | awk '{print $4}'`


RESULT=`keystone ec2-credentials-create --tenant_id=$USER1_TENANT --user_id=$USER1_USER`
USER1_ACCESS=`echo "$RESULT" | grep access | awk '{print $4}'`
USER1_SECRET=`echo "$RESULT" | grep secret | awk '{print $4}'`

RESULT=`keystone ec2-credentials-create --tenant_id=$USER2_TENANT --user_id=$USER2_USER`
USER2_ACCESS=`echo "$RESULT" | grep access | awk '{print $4}'`
USER2_SECRET=`echo "$RESULT" | grep secret | awk '{print $4}'`

cat > /root/.openstackrc <<EOF
#COMMON ENV OPTIONS FOR FIRESTACK INIT SCRIPTS

# disable keyring caching in python-keystoneclient
export OS_NO_CACHE=\${OS_NO_CACHE:-1}

# legacy options for novaclient
export NOVA_API_KEY="\$OS_PASSWORD"
export NOVA_USERNAME="\$OS_USERNAME"
export NOVA_PROJECT_ID="\$OS_TENANT_NAME"
export NOVA_URL="\$OS_AUTH_URL"
export NOVA_VERSION="1.1"

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

#admin (openstackrc)
cat > /root/openstackrc <<EOF
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASSWORD
export OS_TENANT_NAME=admin
export OS_AUTH_URL=$AUTH_ENDPOINT
export OS_AUTH_STRATEGY=keystone

export EC2_ACCESS_KEY=$ADMIN_ACCESS
export EC2_SECRET_KEY=$ADMIN_SECRET

source $HOME/.openstackrc
EOF

#user1
cat > /root/user1rc <<EOF
export OS_USERNAME=user1
export OS_PASSWORD=$USER1_PASSWORD
export OS_TENANT_NAME=user1
export OS_AUTH_URL=$AUTH_ENDPOINT
export OS_AUTH_STRATEGY=keystone

export EC2_ACCESS_KEY=$USER1_ACCESS
export EC2_SECRET_KEY=$USER1_SECRET

source $HOME/.openstackrc
EOF

#user2
cat > /root/user2rc <<EOF
export OS_USERNAME=user2
export OS_PASSWORD=$USER2_PASSWORD
export OS_TENANT_NAME=user2
export OS_AUTH_URL=$AUTH_ENDPOINT
export OS_AUTH_STRATEGY=keystone

export EC2_ACCESS_KEY=$USER2_ACCESS
export EC2_SECRET_KEY=$USER2_SECRET

source $HOME/.openstackrc
EOF

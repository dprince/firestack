#!/bin/bash
export SERVICE_TOKEN=$SERVICE_TOKEN
export SERVICE_ENDPOINT=$SERVICE_ENDPOINT
export AUTH_ENDPOINT=$AUTH_ENDPOINT
export OS_NO_CACHE=1

# Actual users are now created via puppet

ADMIN_PASSWORD="AABBCC112233"
USER1_PASSWORD="DDEEFF445566"
USER2_PASSWORD="GGHHII778899"
ADMIN_TENANT=$(keystone tenant-list | grep admin | cut -f 2 -d " ")
USER1_TENANT=$(keystone tenant-list | grep user1 | cut -f 2 -d " ")
USER2_TENANT=$(keystone tenant-list | grep user2 | cut -f 2 -d " ")

ADMIN_USER=$(keystone user-list | grep admin | cut -f 2 -d " ")
USER1_USER=$(keystone user-list | grep user1 | cut -f 2 -d " ")
USER2_USER=$(keystone user-list | grep user2 | cut -f 2 -d " ")

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

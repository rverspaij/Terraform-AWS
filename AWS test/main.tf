provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyVPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "PublicSubnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "PrivateSubnet"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "InternetGateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "PublicRouteTable"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "public_route_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "PrivateRouteTable"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "private_route_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "sg" {
  name   = "Allow Traffic"
  vpc_id = aws_vpc.my_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    iterator = port
    for_each = var.ingressrules
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

/* resource "time_sleep" "wait" {
  create_duration = "360s"
} */

resource "aws_instance" "Nagios" {
  ami                         = "ami-053b0d53c279acc90"
  instance_type               = "t2.large"
  subnet_id                   = aws_subnet.private_subnet.id
  associate_public_ip_address = true
  private_ip                  = "10.0.2.20"
  vpc_security_group_ids      = [aws_security_group.sg.id]
  tags = {
    Name = "NagiosServer"
  }

  user_data = <<-EOL
  #!/bin/bash -xe
  
  sudo su
  
  apt-get install apt-transport-https zip unzip lsb-release curl gnupg -y
  
  curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/elasticsearch.gpg --import && chmod 644 /usr/share/keyrings/elasticsearch.gpg
  
  echo "deb [signed-by=/usr/share/keyrings/elasticsearch.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list
  
  apt-get update
  
  apt-get install elasticsearch=7.17.9
  
  curl -so /etc/elasticsearch/elasticsearch.yml https://packages.wazuh.com/4.4/tpl/elastic-basic/elasticsearch_all_in_one.yml
  
  curl -so /usr/share/elasticsearch/instances.yml https://packages.wazuh.com/4.4/tpl/elastic-basic/instances_aio.yml
  
  /usr/share/elasticsearch/bin/elasticsearch-certutil cert ca --pem --in instances.yml --keep-ca-key --out ~/certs.zip
  
  unzip ~/certs.zip -d ~/certs

  mkdir /etc/elasticsearch/certs/ca -p
  cp -R ~/certs/ca/ ~/certs/elasticsearch/* /etc/elasticsearch/certs/
  chown -R elasticsearch: /etc/elasticsearch/certs
  chmod -R 500 /etc/elasticsearch/certs
  chmod 400 /etc/elasticsearch/certs/ca/ca.* /etc/elasticsearch/certs/elasticsearch.*
  rm -rf ~/certs/ ~/certs.zip

  systemctl daemon-reload
  systemctl enable elasticsearch
  systemctl start elasticsearch

  /usr/share/elasticsearch/bin/elasticsearch-setup-passwords interactive -b << EOF
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  Welkom123
  EOF
  
  curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
  echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
  apt-get update

  apt-get install wazuh-manager

  systemctl daemon-reload
  systemctl enable wazuh-manager
  systemctl start wazuh-manager

  systemctl status wazuh-manager

  apt-get install filebeat=7.17.9
  curl -so /etc/filebeat/filebeat.yml https://packages.wazuh.com/4.4/tpl/elastic-basic/filebeat_all_in_one.yml

  curl -so /etc/filebeat/wazuh-template.json https://raw.githubusercontent.com/wazuh/wazuh/4.4/extensions/elasticsearch/7.x/wazuh-template.json
  chmod go+r /etc/filebeat/wazuh-template.json

  curl -s https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.2.tar.gz | tar -xvz -C /usr/share/filebeat/module

  sed -i 's/output.elasticsearch.password: <elasticsearch_password>/output.elasticsearch.password: Welkom123/' /etc/filebeat/filebeat.yml

  cp -r /etc/elasticsearch/certs/ca/ /etc/filebeat/certs/
  cp /etc/elasticsearch/certs/elasticsearch.crt /etc/filebeat/certs/filebeat.crt
  cp /etc/elasticsearch/certs/elasticsearch.key /etc/filebeat/certs/filebeat.key

  systemctl daemon-reload
  systemctl enable filebeat
  systemctl start filebeat
  
  apt-get install kibana=7.17.9

  mkdir /etc/kibana/certs/ca -p
  cp -R /etc/elasticsearch/certs/ca/ /etc/kibana/certs/
  cp /etc/elasticsearch/certs/elasticsearch.key /etc/kibana/certs/kibana.key
  cp /etc/elasticsearch/certs/elasticsearch.crt /etc/kibana/certs/kibana.crt
  chown -R kibana:kibana /etc/kibana/
  chmod -R 500 /etc/kibana/certs
  chmod 440 /etc/kibana/certs/ca/ca.* /etc/kibana/certs/kibana.*
  
  curl -so /etc/kibana/kibana.yml https://packages.wazuh.com/4.4/tpl/elastic-basic/kibana_all_in_one.yml

  sed -i 's/elasticsearch.password: <elasticsearch_password>/elasticsearch.password: Welkom123/' /etc/kibana/kibana.yml

  mkdir /usr/share/kibana/data
  chown -R kibana:kibana /usr/share/kibana
  
  cd /usr/share/kibana
  sudo -u kibana /usr/share/kibana/bin/kibana-plugin install https://packages.wazuh.com/4.x/ui/kibana/wazuh_kibana-4.4.3_7.17.9-1.zip
  
  setcap 'cap_net_bind_service=+ep' /usr/share/kibana/node/bin/node

  systemctl daemon-reload
  systemctl enable kibana
  systemctl start kibana
  EOL
}

resource "aws_instance" "Agent" {
  ami                         = "ami-053b0d53c279acc90"
  instance_type               = "t2.large"
  subnet_id                   = aws_subnet.private_subnet.id
  associate_public_ip_address = true
  private_ip                  = "10.0.2.10"
  vpc_security_group_ids      = [aws_security_group.sg.id]
  tags = {
    Name = "Agent"
  }
  /* depends_on = [time_sleep.wait] */

  user_data = data.template_file.script.rendered
}

data "template_file" "script" {
  template = file("${path.module}/script.sh")
}

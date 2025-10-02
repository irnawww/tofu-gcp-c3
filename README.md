# Challenge 3: Infrastructure as Code (IaC)  
## Task: Provision a Simple Web Server using OpenTofu  

Project ini menggunakan **OpenTofu (Terraform fork)** untuk melakukan provisioning infrastruktur secara otomatis di **Oracle Cloud Infrastructure (OCI)** dengan memanfaatkan free tier.  
Konfigurasi IaC ini akan membuat:  
- Sebuah **Virtual Machine (VM)**.  
- Aturan firewall (security list) untuk mengizinkan inbound HTTP (port 80) dan SSH (port 22).  
- VM otomatis menginstal **Nginx** dan menampilkan halaman sederhana `"Hello, OpenTofu!"` menggunakan startup script.  
- Output berupa **public IP** dari VM yang berhasil diprovision.  

---

## Prerequisites  

Sebelum menjalankan konfigurasi, pastikan:  
1. **OpenTofu** sudah terinstal.  
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y curl unzip git
   curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
   chmod +x install-opentofu.sh
   ./install-opentofu.sh --install-method standalone
   rm install-opentofu.sh
   ```
2. OCI Credentials sudah tersedia (tenancy OCID, user OCID, fingerprint, private key, region, dsb).  

Konfigurasi
### main.tf

Berisi definisi resource di OCI:
VCN & Subnet
Internet Gateway & Route Table
Security List (firewall) untuk port 22 & 80
Compute Instance (VM) dengan metadata startup script
```
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# Virtual Cloud Network
resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "opentofu-vcn"
  cidr_block     = "10.0.0.0/16"
}

# Subnet
resource "oci_core_subnet" "subnet" {
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.vcn.id
  cidr_block          = "10.0.1.0/24"
  display_name        = "opentofu-subnet"
  prohibit_public_ip_on_vnic = false
}

# Internet Gateway
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "opentofu-igw"
}

# Route Table
resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "opentofu-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Security List
resource "oci_core_security_list" "sec_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "opentofu-sec-list"

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 22, max = 22 }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 80, max = 80 }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Compute Instance
resource "oci_core_instance" "vm" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "opentofu-vm"
  shape               = var.instance_shape

  create_vnic_details {
    subnet_id        = oci_core_subnet.subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = var.image_ocid
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key)
    user_data           = base64encode(file("userdata.sh"))
  }
}
```

### variables.tf
```
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}
variable "compartment_ocid" {}
variable "availability_domain" {}
variable "ssh_public_key" {}
variable "instance_shape" {
  default = "VM.Standard.E2.1.Micro" # free tier
}
variable "image_ocid" {
  description = "Oracle Linux image OCID for your region"
}
```
### outputs.tf
```
output "public_ip" {
  description = "Public IP address of the VM"
  value       = oci_core_instance.vm.public_ip
}
```
### userdata.sh
```
#!/bin/bash
sudo yum update -y
sudo yum install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

echo "Hello, OpenTofu!" | sudo tee /usr/share/nginx/html/index.html
```

### Cara menjalankan
### 1. Inisialisasi OpenTofu
```
tofu init
```
### 2. Untuk melihat rencana eksekusi
```
tofu plan
```
### 3. Provision infrastruktur
```
tofu apply
```
Setelah selesai, output akan menampilkan public IP dari VM.
### 4. Akses web server
Buka browser:
```
http://<public_ip>
```
Maka akan muncul halaman:
```
Hello, OpenTofu!
```
Seperti pada Gambar berikut:
<img width="276" height="86" alt="image" src="https://github.com/user-attachments/assets/c7ee3cd7-ba0d-47d5-b64b-36a9cc1cb721" />



### Menghancurkan Resource
Jika sudah tidak diperlukan, semua resource bisa dihancurkan dengan:
```
tofu destroy
```

### Kesimpulan Challenge 3: Infrastructure as Code
Konfigurasi ini berhasil memenuhi seluruh requirement challange:
- Menggunakan OpenTofu untuk provisioning di OCI free tier.
- Membuat VM instance dengan aturan firewall untuk HTTP (80) dan SSH (22).
- VM otomatis menginstal Nginx melalui startup script.
- Output menampilkan public IP dari instance.




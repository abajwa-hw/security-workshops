## Enable security on HDP 2.2 single node setup using *FreeIPA* as LDAP


#### Setup LDAP: Install a CentOS VM from iso and install FreeIPA on it using instructions here

- How to integrate with LDAP?
  - [IPA](http://freeipa.org) (Identity Policy Audit) is an integrated solution developed by [Red Hat](http://www.redhat.com) that wraps an LDAP/DNS/NTP/Kerberos server together. It makes it easy to implement a kerberos solution and to get users access to a cluster. 

- Setup details
  - We will be using a 2 VM setup: one with LDAP and one with HDP 2.2. In this example we will be using a single node HDP 2.2 setup installed via Ambari with Hue setup
  - The official 2.2 sandbox is not being used as it already has Ranger installed.



####  Part 0: Setup and start LDAP and HDP Virtual Machines
- Install Centos 6.5 on on VM and setup FreeIPA using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-LDAP-IPA.md)
- Download prebuilt HDP 2.2 GA sandbox VM image with Hue from [here](https://dl.dropboxusercontent.com/u/114020/Hortonworks_2.2_GA.ova). Import Hortonworks_2.2_GA.ova into VirtualBox/VMWare and configure its memory size to be at least 8GB RAM and start VM
       
#### Part 1: Authentication                       
Configure kerberos with LDAP on single node running HDP 2.2 using IPA. Instructions [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-IPA.md)
             
#### Part 2: Authorization/Audit
Setup Ranger and authorization policies and review audit reports from a Rangers Policy Manager using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md)
            
          
#### Part 3: Perimeter Security
Enable Knox to work with kerberos enabled cluster to enable perimeter security using single end point using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-21.md)

#### Other resources


- Sample script to setup volume encryption using LUKS 
```
#This is usually done on a volume

#Create the LUKS key. Enter: 
cryptsetup luksFormat /dev/sdb
#Cryptsetup displays a request for confirmation. Enter YES. (all uppercase)

#Open the drive as encrypted. Enter:
cryptsetup luksOpen /dev/sdb crypted_disk2

#Create a key for the encrypted disk. Enter:
`dd if=/dev/urandom of=mydisk.key bs=1024 count=4` chmod 0400 mydisk.key

#Register the key for the encrypted disk. Enter:
cryptsetup luksAddKey /dev/sdb mydisk.key

#Format the encrypted disk/drive, Enter:
mkfs.ext4 /dev/mapper/crypted_disk2    

#auto mount instruction to /etc/fstab
mkdir -p /encrypted_folder
echo "/dev/mapper/crypted_disk2 /encrypted_folder ext4 defaults,nofail 1 2" >> /etc/fstab/ 
mount -a

#Add the disk key to /etc/crypttab. This is important, else it won’t auto mount
echo "crypted_disk2 /dev/sdb mydisk.key luks" >> /etc/crypttab
```


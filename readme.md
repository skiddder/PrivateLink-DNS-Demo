# Description
This script deploys a hub & spoke including a client VM in spoke-1 and a Windows-based DNS server in the hub. Additionally, a vnet is created to mimick onprem environment including a Windows based DNS server and a client for testing.
As this environment demonstrates how to configure DNS for private link including onprem forwarding, a blob storage account gets created as well as a private endpoint and the private DNS zone including an A RECORD for the blob storage service.
please note: The terraform currently does not include the configuration of the Windows based DNS servers.
# Installation
1. edit the start-config.sh file and provide the following values:

| variable name   | description                        |
|-----------------|------------------------------------|
| admin_username  | local login account for all VMs    |
| public_key      | public ssh key string for linux login. You can get it by executing the command 'cat ~/.ssh/rsa_id.pub'     |
| admin_password  | password for local windows login   |


2. Execute the start-config.sh script. Make sure it has execute permissions in your local directory:
``` bash
az login
az account show 

# validate that you are in the wanted subscription for deployment before you execute start-config.sh
./start-config.sh
```

The script uses terraform to deploy all Azure resources. On the windows DNS servers it also executes a post deployment script to enable WinRM which is required for ansible configuration.
In the last step the ansible playbook is being applied to the Windows DNS servers to configure the required forwardings:

    - on the VM az-dns-srv general forwarding to IP address 168.63.129.16 is set.
    
    - on the VM onprem-dns-srv conditional forwardings for contoso.local and blob.core.windows.net to IP address of the VM az-dns-srv which should have the IP address 10.20.0.4 are configured.

# Validate the deployment
Connect to the dns-client in spoke-1 and to the onprem-client in onprem-vnet and try a dns resolution for the storage account. You can find the public ips of the vms in outlook.txt after you executed start-config.sh.
``` bash
ssh -i ~/.ssh/<path-to-the-ssh-private-keyfile> <replace-with-your-admin_user>@<replace-with-pip>
nslookup mdnstafh53.blob.core.windows.net
```

The result should look like this:
``` bash
Server:         10.20.0.4
Address:        10.20.0.4#53

Non-authoritative answer:
mdnstafh53.blob.core.windows.net        canonical name = mdnstafh53.privatelink.blob.core.windows.net.
Name:   mdnstafh53.privatelink.blob.core.windows.net
Address: 10.20.0.5
```
- In the azurerm provider version used for deployment, you cannot set the 'fallback to Internet' option, yet. Hence, you might need to configure it manually on the azurerm_private_dns_zone_virtual_network_link object(s).

- In case the linux dns clients are not configured out-of-the box to use the nameserver specified by the Azure Vnet, you can troubleshoot the settings as explained [here](https://learnubuntu.com/change-dns-server/). 


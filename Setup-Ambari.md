# Securing Ambari

Methods of securing Ambari:

- Ambari authentication via LDAP or Active Directory
- Encrypt Database and LDAP Passwords
- HTTPS for Ambari server
- Kerberos for Ambari Server
- Two-Way SSL Between Ambari Server and Ambari Agents
- non-root Ambari Server
- non-root Ambari Agents

Documentation:

- http://docs.hortonworks.com/ -> Ambari -> Ambari Security Guide
- http://docs.hortonworks.com/ -> Ambari -> Configuring Ambari for Non-Root

--------

## Authentication via LDAP or Active Directory

The following uses FreeIPA as detailed in the [Kerberos Guide](./Setup-kerberos-IPA-23.md). The steps can be modified for any LDAP service.

More detail available at http://docs.hortonworks.com/ -> Ambari -> Ambari Security

1. Configure Ambari for LDAP

```
sudo ambari-server setup-ldap
```

Press enter for the default unless specified below.
- For the password, use your LDAP admin password. In our guide it is `hortonworks`.

```
Primary URL* {host:port} : ldap.hortonworks.com:389
Secondary URL {host:port} :
Use SSL* [true/false] (false):
User object class* (posixAccount):
User name attribute* (uid):
Group object class* (posixGroup):
Group name attribute* (cn):
Group member attribute* (memberUid):
Distinguished name attribute* (dn):
Base DN* : cn=accounts,dc=hortonworks,dc=com
Referral method [follow/ignore] :
Bind anonymously* [true/false] (false):
Manager DN* : uid=admin,cn=users,cn=accounts,dc=hortonworks,dc=com
```

2. Restart Ambari server and sync ldap

```
sudo ambari-server restart
sudo ambari-server sync-ldap --all
## When prompted:
##   User: admin
##   Pass: hortonworks (or whatever you set in IPA)
sudo ambari-server restart ## just to make sure it comes up after
sudo ambari-agent restart
```

3. Login to Ambari as any LDAP user.

- Example:
  - Login as paul/hortonworks and notice he has no views
  - Login as admin and then pull down the drop down on upper right select "Manage Ambari". From here admins can 
    - Click users, select a particular user and make them an Ambari Admin add paul as Ambari admin 
    - Click Views from where they can create instances of views and assign him specific views
- now re-try as paul and notice the change.

--------

## TODO: Kerberos for Ambari

## TODO: Ambari HTTPS

## TODO: Setup views on kerborized setup
  - Need to test/automate steps mentioned here: https://docs.google.com/document/d/1z9g3yfPiB7pek_eQ1SLzZjOOrXDEPhtFcWYfMK1i6XA/edit#heading=h.4vbz7raxa0ww

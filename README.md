## Securing the Hadoop Data Lake workshop

These workshops is part of a 'Securing the Data Lake' webinar.

The full list of available workshops is available at http://hortonworks.com/partners/learn

#### Goals 
To demonstrate: 
- Authentication: Configure kerberos with LDAP on HDP sandbox 
- Authorization & Audit: To allow users to specify access policies and enable audit around Hadoop from a central location via a UI, integrated with LDAP
- Enable Perimeter Security: Enable Knox to work with kerberos enabled cluster to enable perimeter security using single end point

Why integrate security with LDAP? 
 - To show how Hadoop plugs in to the enterprise's existing Identity Management system


#### Workshop Materials

##### Current release:

1. Enable security on **HDP 2.2.4.2/Ambari 2.0** single node setup using **OpenLDAP** as LDAP
  - Instructions available [here](https://github.com/abajwa-hw/security-workshops/blob/master/Security-workshop-HDP%202_2_4_2-openLDAP.md) 

Note that FreeIPA will not work with Ambari 2.0 because the manual kerberos wizard option was removed. This will be added back in future release (by end of summer)

##### Beta release:

1. Enable security on **HDP 2.3/Ambari 2.1** single node setup using **FreeIPA** as LDAP
  - Instructions available [here](https://github.com/abajwa-hw/security-workshops/blob/master/Security-workshop-HDP 2_3-IPA.md) 


##### Previous releases:

**HDP 2.2.0**

1. Enable security on **HDP 2.2.0** single node setup using **FreeIPA** as LDAP
  - Instructions available [here](https://github.com/abajwa-hw/security-workshops/blob/master/Security-workshop-HDP%202_2-seperateIPA.md) 
  - Prebuilt secured sandbox VM available [here](https://www.dropbox.com/sh/hqpxjumrxf6j27s/AADQeY69-e92hYTHBr664sSaa?dl=0)

2. Enable security on **HDP 2.2.0** single node setup using **OpenLDAP** as LDAP
  - Instructions available [here](https://github.com/abajwa-hw/security-workshops/blob/master/Security-workshop-HDP%202_2-openLDAP.md) - **WIP**

**HDP 2.1**

3. Enable security on **HDP 2.1** sandbox using **FreeIPA** as LDAP
  - [Presentation Slides](http://www.slideshare.net/hortonworks/hdp-security-overview) of presentation
  - [Presentation Recording](https://hortonworks.webex.com/hortonworks/lsr.php?RCID=ba69eaa5bbf49d3c9d4df7f94e0201f6) of presentation
  - Instructions available [here](https://github.com/abajwa-hw/security-workshops/blob/master/Security-workshop-HDP%202_1-seperateIPA.md)
  - Step by step video playlist available [here](https://www.youtube.com/playlist?list=PL2y_WpKCCNQc7S25MOWUB0kZJMrivatWj)
  - Prebuilt secured sandbox VM available [here](https://www.dropbox.com/sh/zllryf6s2fvlv6b/AAD62NDmJZ7QFFiZ86Mkz_1Ia?dl=0)



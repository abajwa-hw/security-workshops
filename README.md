## Securing the Hadoop Data Lake workshop

These workshops is part of a 'Securing the Data Lake' webinar.

The webinar recording and slides are available at http://hortonworks.com/partners/learn

#### Goals 
To demonstrate: 
- Authentication: Configure kerberos with LDAP on HDP sandbox 
- Authorization & Audit: To allow users to specify access policies and enable audit around Hadoop from a central location via a UI, integrated with LDAP
- Enable Perimeter Security: Enable Knox to work with kerberos enabled cluster to enable perimeter security using single end point

Why integrate security with LDAP? 
 - To show how Hadoop plugins into the enterprises existing Identity Management system

#### Materials
- [Slides](http://www.slideshare.net/hortonworks/hdp-security-overview)
- [Recording](https://hortonworks.webex.com/hortonworks/lsr.php?RCID=ba69eaa5bbf49d3c9d4df7f94e0201f6)


#### Workshop Instructions

1. Enable security on **HDP 2.1** sandbox using **FreeIPA** as LDAP.
  - [Youtube video playlist available here](https://www.youtube.com/playlist?list=PL2y_WpKCCNQc7S25MOWUB0kZJMrivatWj)
  - [Prebuilt secured sandbox VM available here](https://www.dropbox.com/sh/zllryf6s2fvlv6b/AAD62NDmJZ7QFFiZ86Mkz_1Ia?dl=0)
  - [Instructions available here](https://github.com/abajwa-hw/security-workshops/blob/master/Security-workshop-HDP%202_1-seperateIPA.md)
  
2. Enable security on **HDP 2.2** single node setup using **FreeIPA** as LDAP. 
  - [Instructions available here](https://github.com/abajwa-hw/security-workshops/blob/master/Security-workshop-HDP%202_2-seperateIPA.md) 

3. Enable security on **HDP 2.2** single node setup using **OpenLDAP** as LDAP.
  - [Instructions available here](https://github.com/abajwa-hw/security-workshops/blob/master/Security-workshop-HDP%202_2-openLDAP.md) - WIP
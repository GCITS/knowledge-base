# Quarantine Azure Blob Storage Phishing Emails

Phishing emails which use Azure Blob Storage are becoming more prevalent. Azure Blob Storage uses a core.windows.net URL, and also includes a valid SSL certificate issued by Microsoft so these phishing attempts can look very convincing. ATP does sandbox these URLs, but if your tenant doesn't have this licence then it won't even be marked as Junk E-Mail.

The scripts will quarantine these emails, however you can modify the script to perform other actions such as send it for approval (`-ModerateMessageByUser $Recipient`) or just delete the email (`-DeleteMessage $true`).

## References
- [Simple Rules to Protect Against Spoofed & windows.net Phishing Attacks](https://malware-research.org/simple-rule-to-protect-against-spoofed-windows-net-phishing-attacks/)
- [THREAT ALERT: Cybercrooks Abusing Microsoft Azure Storage Custom Domain Name Feature](https://blog.appriver.com/malicious-actors-abusing-microsoft-azure-storage-custom-domain-name-feature)
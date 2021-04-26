#!/bin/bash

# Cette fonction permet de poser des questions
ecrire_question(){
	repok="nok"
	while [ $repok != 'ok' ]
	do
		read -p "$1" reponse
		if [ -n $2 ] && [ $2 = "ouinon" ];then # impose une reponse fermee
			if [ ! -z $reponse ] && ( [ $reponse = "o" ] || [ $reponse = "n" ] );then
				repok="ok" 
			fi
		elif [ -n $2 ] && [ $2 = "mail" ];then # impose une reponse avec un mail
			if [ ! -z $reponse ] && [[ $reponse =~ ^[^\W][a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*\@[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*\.[a-zA-Z]{2,14}$ ]];then
				repok="ok"
			fi
		elif [ -n $2 ] && [ $2 = "port" ];then # impose une reponse avec un numero de port
			#printf -v int '%d\n' "$reponse" 2>/dev/null
			if [ ! -z $reponse ] && [[ "$reponse" =~ ^[0-9]+$ ]] && [ $reponse -le 65535 ] && [ $reponse -ge 1 ];then
				repok="ok"
			fi
		elif [ -n $2 ] && [ $2 = "texte" ];then # accepte toutes les réponses non vides
			if [ ! -z $reponse ];then
				repok="ok" 
			fi
		elif [ -n $2 ] && [ $2 = "chiffre" ];then # accepte toutes les réponses en chiffre
			#printf -v int '%d\n' "$reponse" 2>/dev/null
			if [ ! -z $reponse ] && [[ "$reponse" =~ ^[0-9]+$ ]];then
				repok="ok" 
			fi
		else # accepte toutes les réponses meme vides
			repok="ok" 
		fi
		if [ $repok = "ok" ];then # revoi de la reponse
			echo $reponse
		fi
	done
}


#mise en place des valeurs par defaut
dolocate="y"
debug="non"
auto="non"
help="no"

aptupdate="o"
aptupgrade="o"
installiptable="o"
protectflood="o"
protectscaniptable="o"
protectscan="o"
protectbruteforce="o"
presentsshport=$( netstat -tpln | grep "ssh" | head -1 | cut -d':' -f2 | cut -d' ' -f1 )
changeportssh="n"
futursshport="22"
maxretryloginssh="5"
bantime="600"
preotectrootkit="o"
mailrkhuter="-"
maillogwatchidemrkhunter="n"
logwatch="o"
maillogwatch="-"

resuminstall="\n\n------------------------------------------\n ------- Resume de l'installation -------\n------------------------------------------\n"

# verifif de la presence des attributs "all" ou "debug"
for attribut in $*
do
	#echo verification de l attribut $attribut
	if [ $attribut = "--all" ] || [[ $attribut =~ ^\-[^-]*a ]];then
		auto="yes"
	fi
	if [ $attribut = "--debug" ] || [[ $attribut =~ ^\-[^-]*d ]];then
		debug="yes"
	fi
	if [ $attribut = "--help" ] || [[ $attribut =~ ^\-[^-]*h ]];then
		help="yes"
	fi
done

#activation du debug
if [ -n $debug ] && [ $debug = "yes" ];then
	set -x
fi

#aide du script
if [ $help = "yes" ];then
	echo -e "\n\n --------------------------------------\n -------- Bienvenue dans l'aide -------\n --------------------------------------\n"
	echo -e "Ce script permet d'automatiser la securisation de votre serveur."
	echo -e "Vous pouvez utiliser les attributs suivant:\n"
	echo -e "-a ou --all permet de tout installer avec les valeurs par defaut"
	echo -e "-d ou --debug permet d'afficher le script au prorata de son execution"
	echo -e "-h ou --help affiche cette aide"
	echo -e "\nexemple: "$0" -h"
	echo -e "ou encore: "$0" -ad"
	echo -e "ou encore: "$0" --all --debug --help\n"
else

	# recup pref utilisateur
	if [ $auto != "yes" ];then
		aptupdate=`ecrire_question "Voulez-vous mettre a jour la liste des packages ? (o/n): " "ouinon"`
		aptupgrade=`ecrire_question "Voulez-vous mettre a jour les packages existants ? (o/n): " "ouinon"`
		installiptable=`ecrire_question "Voulez-vous installer le firewall IPtable ? (o/n): " "ouinon"`
		protectflood=`ecrire_question "Voulez-vous installer la protection contre le flood ou deni de service avec IPtable ? (o/n): " "ouinon"`
		protectscaniptable=`ecrire_question "Voulez-vous installer une protection contre les scan de port avec IPtable ? (o/n): " "ouinon"`
		protectscan=`ecrire_question "Voulez-vous installer une protection contre les scan de port avec Portsentry ? (o/n): " "ouinon"`
		protectbruteforce=`ecrire_question "Voulez-vous installer une protection contre le brute-force, dictionnaire, deni de service avec Fail2ban ? (o/n): " "ouinon"`
		changeportssh=`ecrire_question "Voulez-vous changer le numero de port SSH (actuellement sur le port TCP $presentsshport) ? (o/n): " "ouinon"`
		if [ $changeportssh = "o" ];then
			futursshport=`ecrire_question "Quel port TCP souhaitez-vous pour le service SSH ? (entre 1 et 65535): " "port"`
		else
			futursshport=$presentsshport
		fi
		maxretryloginssh=`ecrire_question "Combien voulez-vous autoriser de tentatives de connexion echouees ? (5 conseillees): " "chiffre"`
		bantime=`ecrire_question "Combien de temps voulez-vous banir l'attaquant (en seconde) ? (600 => 10min, 3600 => 1h, 86400 => 1j, ... ): " "chiffre"`
	fi
	if [ $auto != "yes" ];then
		preotectrootkit=`ecrire_question "Voulez-vous installer une protection contre les rootkits et backdoors avec Rkhunter ? (o/n): " "ouinon"`
	fi
	if [ $preotectrootkit = "o" ];then
		mailrkhuter=`ecrire_question "Indiquez le mail d'alerte de Rkhunter : " "mail"`
	fi
	if [ $auto != "yes" ];then
		logwatch=`ecrire_question "Voulez-vous installer le logiciel d'analyse de logs logwatch ? (o/n): " "ouinon"`
	fi
	if [ $logwatch = "o" ];then
		if [ $mailrkhuter != "-" ];then
			maillogwatchidemrkhunter=`ecrire_question "Voulez-vous utiliser le mail "$mailrkhuter" pour les alertes de Logwatch ? (o/n)" "ouinon"`
		fi
		if [ $maillogwatchidemrkhunter = "o" ];then
			maillogwatch=$mailrkhuter
		else
			maillogwatch=`ecrire_question "Indiquez le mail d'alerte de logwatch : " "mail"`
		fi
		
	fi
	# Mettre a jour la liste des packages
	if [ $aptupdate = "o" ];then
		installok="no"
		apt-get -y update && installok="yes" && resuminstall=$resuminstall"La liste des packages est finalisee.\n"
		if [ $installok = "no" ];then
			resuminstall=$resuminstall"!!!La liste des packages n'a pas ete finalisee. (apt-get -y update)!!!\n"
		fi
	else
		resuminstall=$resuminstall"---La liste des packages n'est pas demandee.---\n"
	fi
	echo -e $resuminstall

	# Mettre a jour les packages existants
	if [ $aptupgrade = "o" ];then
		installok="no"
		apt-get -y upgrade && installok="yes" && resuminstall=$resuminstall"La mise a jour des packages existants est finalisee.\n"
		if [ $installok = "no" ];then
			resuminstall=$resuminstall"!!!La mise a jour des packages existants n'a pas ete finalisee. (apt-get -y upgrade)!!!\n"
		fi
	else
		resuminstall=$resuminstall"---La mise a jour des packages existants n'est pas demandee.---\n"
	fi
	echo -e $resuminstall

	# Installer le firewall IPtable
	if [ $installiptable = "o" ];then
		installok="no"
		apt-get install iptables -y && installok="yes" && resuminstall=$resuminstall"L'installation du firewall IPtable est finalisee.\n"
		if [ $installok = "no" ];then
			resuminstall=$resuminstall"!!!L'installation du firewall IPtable n'a pas ete finalisee. (apt-get install iptables -y)!!!\n"
		fi
	else
		resuminstall=$resuminstall"---L'installation du firewall IPtable n'est pas demandee.---\n"
	fi
	echo -e $resuminstall

	# Installer la protection contre le flood ou deni de service avec IPtable
	if [ $protectflood = "o" ];then
		installok="no"
		iptables -A FORWARD -p tcp --syn -m limit --limit 1/second -j ACCEPT && iptables -A FORWARD -p udp -m limit --limit 1/second -j ACCEPT && iptables -A FORWARD -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT && installok="yes" && resuminstall=$resuminstall"L'installation de la protection contre le flood ou deni de service avec IPtable est finalisee.\n"
		if [ $installok = "no" ];then
			resuminstall=$resuminstall"!!!L'installation de la protection contre le flood ou deni de service avec IPtable n'a pas ete finalisee. (iptables -A FORWARD -p tcp --syn -m limit --limit 1/second -j ACCEPT && iptables -A FORWARD -p udp -m limit --limit 1/second -j ACCEPT && iptables -A FORWARD -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT )!!!\n"
		fi
	else
		resuminstall=$resuminstall"---L'installation de la protection contre le flood ou deni de service avec IPtable n'est pas demandee.---\n"
	fi
	echo -e $resuminstall

	# Installer une protection contre les scan de port avec IPtable
	if [ $protectscaniptable = "o" ];then
		installok="no"
		iptables -A FORWARD -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -j ACCEPT && installok="yes" && resuminstall=$resuminstall"L'installation d'une protection contre les scan de port avec IPtable est finalisee.\n"
		if [ $installok = "no" ];then
			resuminstall=$resuminstall"!!!L'installation d'une protection contre les scan de port avec IPtable n'a pas ete finalisee. (iptables -A FORWARD -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -j ACCEPT)!!!\n"
		fi
	else
		resuminstall=$resuminstall"---L'installation d'une protection contre les scan de port avec IPtable n'est pas demandee.---\n"
	fi
	echo -e $resuminstall

	# Installer une protection contre les scan de port avec Portsentry
	if [ $protectscan = "o" ];then
		installok="no"
		apt-get install portsentry -y
		if [ -f "/etc/portsentry/portsentry.conf" ];then 
			fileconfportsentry="/etc/portsentry/portsentry.conf"
		elif [ -f "/usr/local/psionic/portsentry/portsentry.conf" ];then
			fileconfportsentry="/usr/local/psionic/portsentry/portsentry.conf"
		else
			if [ $dolocate = "y" ];then
				updatedb
			fi
			fileconfportsentry='locate -r \"portsentry.conf\$\"'
		fi
		for fichier in $fileconfportsentry
		do
			#Commentez les lignes KILL_HOSTS_DENY
			sed -i -e "s/KILL_HOSTS_DENY/\#KILL_HOSTS_DENY/g" "$fichier"
			#Décommentez la ligne KILL_ROUTE="/sbin/iptables -I INPUT-s $TARGET$ -j DROP"
			sed -i -e "s/\#KILL_ROUTE=\"\/sbin\/iptables -I INPUT-s \$TARGET$ -j DROP\"/KILL_ROUTE=\"\/sbin\/iptables -I INPUT-s \$TARGET\$ -j DROP\"/g" "$fichier"
			installok="yes"
		done
		if [ $installok="yes" ];then
		resuminstall=$resuminstall"L'installation d'une protection contre les scan de port avec Portsentry est finalisee.\n"
		fi
		if [ $installok = "no" ];then
			resuminstall=$resuminstall"!!!L'installation d'une protection contre les scan de port avec Portsentry n'a pas ete finalisee. ()!!!\n"
		fi
	else
		resuminstall=$resuminstall"---L'installation d'une protection contre les scan de port avec Portsentry n'est pas demandee.---\n"
	fi
	echo -e $resuminstall

	# Installer une protection contre le brute-force, dictionnaire, deni de service avec Fail2ban
	if [ $protectbruteforce = "o" ];then
		installok="no"
		apt-get install fail2ban -y
		if [ -f "/etc/fail2ban/jail.conf" ];then 
			fileconffail2ban="/etc/fail2ban/jail.conf"
		else
			if [ $dolocate = "y" ];then
				updatedb
			fi
			fileconffail2ban='locate -r \"jail.conf\$\"'
		fi
		for fichier in $fileconffail2ban
		do

			#Remplacer le port dans le fichier jail.conf
				#sed -ine "/^\[section\]/,/^variable*/{s/^variable.*/replacement = value/}" myfile.conf
			sed -in "/^\[ssh\]/,/^port*/{s/^port.*/port = $futursshport/}" "$fichier"
			
			#changement du port SSH pour open SSH
			sed -i -e "s/^#Port.*/Port = $futursshport/g" /etc/ssh/sshd_config
			
			#nombre de tentatives
			sed -i -e "s/^maxretry.*/maxretry = $maxretryloginssh/g" /etc/fail2ban/jail.conf 
			
			#temps de bannissement
			sed -i -e "s/^bantime.*/bantime = $bantime/g" /etc/fail2ban/jail.conf 

			installok="yes"
		done
		if [ $installok="yes" ];then
		resuminstall=$resuminstall"L'installation d'une protection contre le brute-force, dictionnaire, deni de service avec Fail2ban est finalisee.\n"
		fi
		if [ $installok = "no" ];then
			resuminstall=$resuminstall"!!!L'installation d'une protection contre le brute-force, dictionnaire, deni de service avec Fail2ban n'a pas ete finalisee. ()!!!\n"
		fi
	else
		resuminstall=$resuminstall"---L'installation d'une protection contre le brute-force, dictionnaire, deni de service avec Fail2ban n'est pas demandee.---\n"
	fi
	echo -e $resuminstall



	# Installer une protection contre les rootkits et backdoors avec Rkhunter

	if [ $protectrootkit="o" ];then
		installok="no"
		mailRKHunter="mail@gmail.com"
		apt-get install rkhunter -y
	
		read -p "Veuillez entrer un mail pour reçevoir des rapports :" reponse
		mailRKHunter=$reponse
		fileconfrkhunter="/etc/default/rkhunter"
		for fichier in $fileconfrkhunter
		do
		
			sed -i "s|REPORT_EMAIL.*=.*""|REPORT_EMAIL="$mailRKHunter"|g" $fichier
			sed -i "s|CRON_DAILY_RUN.*=.*""|CRON_DAILY_RUN="yes"|g" $fichier
			installok="yes"
		done

		if [ $installok="yes" ];then
			resuminstall=$resuminstall"L'installation d'une protection contre les rootkits et backdoors avec Rkhunter est finalisee.\n\n"
		else
			resuminstall=$resuminstall"!!!L'installation d'une protection contre les rootkits et backdoors avec Rkhunter n'a pas ete finalisee. ()!!!\n\n"
		fi
	else
		resuminstall=$resuminstall"---L'installation d'une protection contre les rootkits et backdoors avec Rkhunter n'est pas demandee.---\n\n"
	fi

	echo -e $resuminstall
	
	
	# Installer le logiciel d'analyse de logs logwatch
	if [ $logwatch = "o" ];then
		installok="no"
		apt-get install -y logwatch \
		&& read -p "Veuillez entrer un mail pour reçevoir des rapports d'analyse de logs:" reponse \
		&& mailLogwatch="$reponse" \
		&& sed -i "s|MailTo.*=.*root|MailTo="$mailLogwatch"|g" /usr/share/logwatch/default.conf/logwatch.conf \
		&& installok="yes" \
		&& resuminstall=$resuminstall"L'installation d'un outil d'analyse de logs Logwatch est finalisee.\n"
		if [ $installok = "no" ];then
			resuminstall=$resuminstall"!!!L'installation d'un outil d'analyse de logs Logwatch n'a pas ete finalisee. ()!!!\n"
		fi
	else
		resuminstall=$resuminstall"---L'installation d'un outil d'analyse de logs Logwatch n'est pas demandee.---\n"
	fi

	echo -e $resuminstall
	
	fi
	
# desactivation du debug
if [ -n $debug ] && [ $debug = "yes" ];then
	set -
fi

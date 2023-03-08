/*
 *		HEC Montr�al
 *		TECH 60701 -- Technologies de l'intelligence d'affaires
 *		Session Automne 2022, Section J01
 *		TP3
 *		Contact: Gregory Vial (gregory.vial@hec.ca)
 *		
 *		Instructions de remise :
 *			- R�pondre aux questions SQL directement dans ce fichier .sql
 *			- La partie de r�flexion de chaque question peut �tre soumise dans un fichier Word s�par� ou en commentaire dans ce fichier SQL, au choix
 *			- La remise du devoir doit �tre effectu�e via ZoneCours dans l'outil de remise de travaux
 *			- Date de remise : voir les dates sur ZoneCours, aucun retard permis
 *
 *		Correction :
 *			- 10% de la note finale, /10
 *			- Une question qui g�n�re une erreur (ne s'ex�cute pas) se verra attribuer automatiquement la note de 0.
 *		
 *		Notes : 
 *			- Le masculin est employ� comme d�nomination g�n�rique � des fins de bri�vet�.
 *			- La question 2 ne peut �tre r�alis�e sur Azure SQL Edge, elle requiert obligatoirement l'utilisation de SQL Server. 
 */

 USE AdventureWorks2019
 GO

/***************** QUESTION 1 *****************/

/* 
Partie A � 10 points (pas de partie B)

	Dans le cadre d'une promotion r�currente, AdventureWorks aimerait, chaque mois, envoyer un courriel aux clients individuels
	dont le nombre d'ann�es entre la date de leur premier achat chez AdventureWorks et la date de leur dernier achat est sup�rieure 
	ou �gale � un chiffre arbitraire (par exemple, 10 ans et plus, 15 ans et plus) etc. AdventureWorks est une entreprise qui existe 
	depuis maintenant longtemps et leurs clients ont effectu� des achats chez eux bien avant l'apparition du syst�me de transaction
	qui est utilis� maintenant et pour lequel vous avez acc�s la base de donn�es.

	L'information consignant la date du premier achat de chaque client est ainsi conserv�e � l'int�rieur d'un champ XML stock� 
	dans la table Person.Person et appel� Demographics. C'est dans ce champ que vous devrez aller r�cup�rer la date du premier
	achat de chaque client individuel afin de le comparer � la date du dernier achat que vous pourrez facilement retrouver dans 
	la table des ventes d'AdventureWorks comme vous avez l'habitude de le faire.

	On a donc besoin d'une fonction avec les sp�cifications suivantes:
		- Le nom de la fonction sera fn_GetLoyalCustomers
		- Le code doit cr�er ou alt�rer la fonction de fa�on autonome (c�d pas besoin d'effacer la fonction manuellement pour la recr�er)
		- Un param�tre en entr�e de type smallint qui repr�sente un nombre d'ann�es minimum. Appelez ce param�re @aNumberOfYears
		- La fonction doit retourner une table avec les informations suivantes: Identifiant de la personne (client individuel), pr�nom, 
		nom de famille, Date de premier achat (voir ci-dessus), date du dernier achat,  nombre d'ann�es entre les deux dates
		- On retournera uniquement les informations des clients dont le nombre d'ann�es sp�cifi� en param�tre est sup�rieur ou �gal � 
		celui pass� en param�tre dans la fonction.

	Pour ce faire, tenez compte des informations suivantes : 
		(1)
			L'extraction de donn�es de champs de type XML dans SQL Server ne se fait pas � travers l'extraction de texte. Il s'agit ici
			d'un type de donn�e structur� avec un sch�ma XML en r�f�rence. Conseil: avant de vous pr�occuper de d�velopper la fonction,
			travaillez sur l'extraction de l'information demand� dans le champ XML. Apr�s, int�grer cela � la requ�te compl�te, et enfin,
			englobez le tout dans la fonction, cela vous facilitera grandement le travail. La documentation de SQL Server fournit diff�rentes
			informations et exemples relatifs � l'extraction de champs XML. On trouve aussi beaucoup de ressources en ligne. Rappelez-vous 
			qu'ici vous voulez aller chercher une valeur dans un attribut de type XML.
		(2)
			Vous pouvez tenir pour acquis que tous les clients individuels fournissent les informations demand�es. Il n'y a pas de valeur NULL
			� anticiper.
		(3)
			Pour tester votre fonction, vous devriez pouvoir ex�cuter la requ�te suivante: SELECT * FROM fn_GetLoyalCustomers(10); Et obtenir ainsi
			la liste des clients dont le nombre d'ann�es entre la date de leur premi�re commande et de leur derni�re commande est sup�rieure ou �gale
			� 10.

*/

-- REPONSE Partie A

CREATE or alter FUNCTION dbo.fn_GetLoyalCustomers(@aNumberOfYears smallint)
RETURNS TABLE
as
return (
select maxdate.PersonID, pp.FirstName,pp.LastName,pp.FirstPurchaseDate,maxdate.LastPurchaseDate,
DATEDIFF(YEAR,pp.FirstPurchaseDate,maxdate.LastPurchaseDate) as YearDifferent
from (select BusinessEntityID as BusinessEntityID , /*sous-requet pour trouver premier achat du client*/
      PersonType as PersonType,FirstName, LastName,
	  Demographics.value('declare namespace IS="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey";             
      (/IS:IndividualSurvey /IS:DateFirstPurchase)[1]', 'date') AS FirstPurchaseDate   
      from person.Person)as pp
inner join (select sc2.PersonID as personID, sc2.CustomerID as customerID ,
      cast(max(soh.OrderDate) as date) as LastPurchaseDate   /*sous-requet pour trouver dernier achat du client*/
      from sales.SalesOrderHeader as soh
      inner join sales.Customer as sc2
      on soh.CustomerID=sc2.CustomerID
      inner join Person.Person as pp2
      on sc2.PersonID=pp2.BusinessEntityID
      group by sc2.PersonID, sc2.CustomerID) as maxdate
on pp.BusinessEntityID=maxdate.personID
where DATEDIFF(YEAR,pp.FirstPurchaseDate,maxdate.LastPurchaseDate)>=@aNumberOfYears and pp.PersonType='IN');
go


Select * 
from dbo.fn_GetLoyalCustomers(10)


-- Partie B
/*
	Pas de partie B
*/



/***************** QUESTION 2 *****************/

/* 
Partie A � 8 points
	Le d�partement de l'exp�dition/r�ception (shippping and receiving) a besoin de votre aide pour l'aider � red�finir le fa�on 
	dont elle calcule les frais de port pour les commandes � envoyer. L'id�e est la suivante: Chaque personne qui a un dossier chez 
	AdventureWorks poss�de au moins une adresse d'exp�dition, tel qu'indiqu� dans la table des commandes des clients SalesOrderHeader.

	Dans l'adresse on retrouve un paquet d'informations int�ressantes mais celle qui est particuli�rement int�ressante ici est 
	l'information contenue dans l'attribut SpatialLocation de la table Person.Address. Manque de chance, quand on consulte cet attribut,
	SQL Server semble retourner tout sauf de l'information de localisation. C'est parce qu'il s'agit d'un champ de type "geography", qui est
	un type sp�cifique utilis� pour des repr�sentations g�ographiques (plus sp�cifiquement c'est un type dit "CLR" qui vient du langage .NET. 
	Il faudra donc apprendre ici � travailler avec ce type d'attribut.

	Pour commencer, ex�cuter une requ�te simple comme: 
		SELECT TOP(10) AddressID, SpatialLocation FROM Person.Address;
	SpatialLocation offre des m�thodes (attention aux majuscules!) comme ToString():
		SELECT TOP(10) AddressID, SpatialLocation, SpatialLocation.ToString() FROM Person.Address;

	On voit ainsi que SpatialLocation offre une longitude et une latitude. On peut �galement les consulter ainsi:
		SELECT TOP(10) 
			AddressID
			, SpatialLocation
			, SpatialLocation.ToString() 
			, SpatialLocation.Long
			, SpatialLocation.Lat
		FROM Person.Address;

	Avec ces informations, on voit donc qu'on peut conna�tre la g�olocalisation exacte d'une adresse directement depuis SQL Server (cool!).
	Dans l'exercice demand� ici, on voudrait calculer la distance entre le QG d'AdventureWorks et chacune des adresses d'exp�dition de commandes
	chez AdventureWorks. �videmment, en th�orie, on devrait calculer cette distance en terme de routes etc. comme le ferait Google Maps.
	Ceci dit, pour faire plus simple, on calculera une distance dite g�od�sique entre deux points: le QG d'AdventureWorks, et l'adresse d'exp�dition
	d'une commande. 

	Voici les �tapes requises pour r�aliser cet exercice:
		(1)
			D�clarer une variable (@HQLocation) pour stocker les coordonn�es du QG d'AventureWorks. Le QG est situ� au Building 9, 1 Microsoft Way Redmond WA.
			En tapant cette adresse sur Google Maps, vous pourrez recopier les coordonn�es dans votre fen�tre SQL.
			Il faut maintenant stocker ces informations dans votre variable, qui est �videmment de type Geography comme SpatialLocation dans la table
			d'adresses. Pour ce faire, consultez la documentation de SQL Server pour cr�er un "point" g�ographique:
			https://docs.microsoft.com/en-us/sql/t-sql/spatial-geography/point-geography-data-type?view=sql-server-ver16

			F�licitations, apr�s cela, vous devriez avoir une variable qui stocke l'adresse du QG d'AventureWorks (qui co�ncide bizarrement avec le QG
			de Microsoft...).
		(2)
			R�diger une requ�te s�par�e qui retourne les informations suivantes: Identifiant de l'adresse, premi�re ligne de l'adresse, ville, nom de la 
			province/�tat, nom du pays, latitude de l'adresse, longitude de l'adresse. Le tout pour les adresses d'exp�dition de commandes chez AdventureWorks.
		(3)
			Ajouter une nouvelle colonne � votre requ�te r�dig�e en (2). Il s'agit de la distance entre les coordonn�es de l'adresse du QG et de chacune des adresses.
			Pour ce faire, consultez la documentation sur calcul de distance dans SQL Server:
			https://docs.microsoft.com/en-us/sql/t-sql/spatial-geography/stdistance-geography-data-type?view=sql-server-ver16
		
			Ouf, vous avez maintenant une belle requ�te qui retourne presque l'information demand�e, bravo! � noter que la distance retourn�e est en m�tres.
			Vous pouvez par exemple v�rifier que grosso modo, les distances que vous avez correspondent � celles qu'on aurait plus ou moins � vol d'oiseau 
			(il y a des d�tails techniques ici dont on se passe mais en gros, �a reste une mesure approximative de distance qui est assez proche d'une vraie
			mesure g�od�sique).
		(4)
			Maintenant, vous devez "packager" votre requ�te dans une fonction intitul�e fn_GetShippingTiers() qui ne prend aucun param�tre. La fonction retourne 
			l'information pr�c�dente avec deux diff�rences. Tout d'abord, on veut maintenant exprimer la distance en kilom�tres, � 2 d�cimales pr�s. Le calcul ne change
			pas vraiment c'est plus du formattage. Deuxi�mement, on veut afficher un tiers reli� �  la distance calcul�e en affichant l'information suivante:
				Distance entre 0 et 25: 'Tiers 1'
				Distance entre 26 et 100: 'Tiers 2'
				Distance entre 101 et 500: 'Tiers 3'
				Distance entre 501 et 5000: 'Tiers 4'
				Distance entre 5001 et 10000: 'Tiers 5'
				Sinon 'Tiers X'

			Ce champ s'appellera "ShippingTier".

		(5)
			Voil�! Maintenant on peut par exemple faire:
				SELECT 
					ShippingTier,
					COUNT(*) AS AddressCount 
					FROM fn_GetShippingTiers()
						GROUP BY ShippingTier ORDER BY 1 ASC;
				GO

			Ce qui devrait retourner:

				ShippingTier AddressCount
				------------ ------------
				Tier 1       935
				Tier 2       1354
				Tier 3       5382
				Tier 4       8370
				Tier 5       7133
				Tier X       8291

*/

-- REPONSE Partie A

CREATE or ALTER FUNCTION dbo.fn_GetShippingTiers()
RETURNS 
@OutputTable TABLE
(
       AddressID int, Addressline VARCHAR(60),City VARCHAR(30), province VARCHAR(50), country VARCHAR(50), longitude FLOAT, latitude FLOAT,
	   DistanceWithHQ FLOAT, DistanKilometre FLOAT, ShippingTier VARCHAR(50)
)
AS
BEGIN
DECLARE  @h geography= geography::STGeomFromText('POINT(-122.127970 47.639458)', 4326);
INSERT INTO @OutputTable
select distinct pa.AddressID, pa.AddressLine1 as Addressline, pa.City, ps.[Name] as province, pc.[Name] as country,
al.locationlong as longitude, al.locationlat as latitude, @h.STDistance(al.SpatialLocation) as DistanceWithHQ,
cast(@h.STDistance(al.SpatialLocation)/1000 as decimal (20,2)) as DistanKilometre, NULL
from sales.SalesOrderHeader as soh
left join Person.Address as pa
on soh.ShipToAddressID=pa.AddressID
inner join (SELECT
			AddressID
			, SpatialLocation
			, SpatialLocation.ToString() as spatialtosting
			, SpatialLocation.Long as locationlong
			, SpatialLocation.Lat as locationlat
		FROM Person.Address) as al
on pa.AddressID=al.AddressID
inner join person.StateProvince as ps
on ps.StateProvinceID=pa.StateProvinceID
inner join person.CountryRegion as pc
on pc.CountryRegionCode=ps.CountryRegionCode

UPDATE @OutputTable
            SET ShippingTier = 
            CASE WHEN (DistanKilometre) < 25 THEN 'Tiers 1'
			WHEN DistanKilometre BETWEEN 25 AND 100 THEN 'Tiers 2'
			WHEN DistanKilometre BETWEEN 100 AND 500 THEN 'Tiers 3'
			WHEN DistanKilometre BETWEEN 500 AND 5000 THEN 'Tiers 4'
			WHEN DistanKilometre BETWEEN 5000 AND 10000 THEN 'Tiers 5'
            ELSE 'Tiers 6'
            END
RETURN
END

select *
from dbo.fn_GetShippingTiers()

SELECT ShippingTier,COUNT(*) AS AddressCount 
	FROM fn_GetShippingTiers()
	GROUP BY ShippingTier ORDER BY 1 ASC;
	GO


-- Partie B
/*
	Pas de partie B
*/


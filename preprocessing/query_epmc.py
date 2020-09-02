#!/usr/bin/env python3
import os
import subprocess as sp
import pandas as pd
import sys
from pandas.io.json import json_normalize
import requests
import time
import re
import codecs
import argparse


def curl_it(accession):
	url="""https://www.ebi.ac.uk/europepmc/webservices/rest/search?query={accession}&resultType=core&format=json""".format(accession=accession)
	data = requests.get(url)
	hitcount = data.json()['hitCount']
	result =data.json()['resultList']['result']
	if result and hitcount == 1:
		_id = [d['id'] if 'id' in d else "NA"  for d in result]
		pmid = [d['pmid'] if 'pmid' in d else "NA"  for d in result]
		source = [d['source'] if 'source' in d else "NA"  for d in result]
		pubtype = [d['pubTypeList']['pubType'] if 'pubTypeList' in d else "NA"  for d in result]
		jessn = [d['journalInfo']['journal']['essn'] if 'journalInfo' in d and 'journal' in d['journalInfo'] and 'essn' in d['journalInfo']['journal'] else "NA"  for d in result][0]
		jissn = [d['journalInfo']['journal']['issn'] if 'journalInfo' in d and 'journal' in d['journalInfo'] and 'issn' in d['journalInfo']['journal'] else "NA"  for d in result][0]

		isopenaccess =[d['isOpenAccess'] if 'isOpenAccess' in d else "NA" for d in result]

		pmcid = [d['pmcid'] if 'pmcid' in d else "NA"  for d in result]
		doi = [d['doi'] if 'doi' in d else "NA"  for d in result]
		author = [d["authorList"]["author"] if 'authorList' in d else "NA" for d in result][0]
		affiliation = [d['affiliation'] if 'affiliation' in d  else "NA" for d in author]
		fullname = [d['fullName'] if 'fullName' in d  else "NA" for d in author]
		orcid = [d['authorId']['value'] if 'authorId' in d  else "NA" for d in author]
		pubdate =  [d['firstPublicationDate'] if 'firstPublicationDate' in d  else "NA" for d in result][0]
		epubdate = [d['electronicPublicationDate'] if 'electronicPublicationDate' in d  else "NA" for d in result][0]
		receiptdate=[d['fullTextReceivedDate'] if 'fullTextReceivedDate' in d  else "NA" for d in result][0]
		revisiondate=[d['dateOfRevision'] if 'dateOfRevision' in d  else "NA" for d in result][0]
		
		# Extra metadata to extract
		title = [d['title'] if 'title' in d else "NA" for d in result]
		abstract = [d['abstractText'] if 'abstractText' in d else "NA" for d in result]
		language = [d['language'] if 'language' in d else "NA" for d in result]
		grantlist = [d['grantsList']['grant'] if 'grantsList' in d  else "NA" for d in result]
		grantid =[d['grantId'] if 'grantId' in d  else "NA" for d in grantlist]
		grantagency = [d['agency'] if 'agency' in d  else "NA" for d in grantlist]
		grantacronym = [d['acronym'] if 'acronym' in d  else "NA" for d in grantlist]
		keywords = [d["keywordList"]["keyword"] if 'keywordList' in d else "NA" for d in result][0]
		if (len(doi)==1 or len(pmid)==1 or len(pmcid)==1):
			for i,name in enumerate(fullname):
				country=affiliation[i].split(',')[-1].replace('.','')
				if (re.search(r"(\w+) ([\w.-]+@[\w.-]+.\w+)",country)):
					match=re.search(r"(\w+) ([\w.-]+@[\w.-]+.\w+)",country)
					etat = match.group(1)
				else:
					etat=country

				print("\t".join([accession, _id[0],source[0], "|".join(pubtype[0]) , jessn + ',' + jissn, 
						isopenaccess[0],  pmid[0], pmcid[0], doi[0], fullname[i], affiliation[i],
						etat, pubdate, epubdate, orcid[i],
						title[0], abstract[0], language[0], ":".join(grantid), ":".join(grantagency), ":".join(grantacronym),
						receiptdate, revisiondate, ", ".join(list(filter(None, keywords))) ]))
	elif result and hitcount >1:
		for i, hit in enumerate(result):
			subset = result[i]
			pmid = subset['pmid'] if 'pmid' in subset else "NA"
			
			_id = subset['id'] if 'id' in subset else "NA" 
			source = subset['source'] if 'source' in subset else "NA"  
			pubtype = subset['pubTypeList']['pubType'] if 'pubTypeList' in subset else "NA"
			jessn = subset['journalInfo']['journal']['essn'] if 'journalInfo' in subset and 'journal' in subset['journalInfo'] and 'essn' in subset['journalInfo']['journal'] else "NA"
			jissn = subset['journalInfo']['journal']['issn'] if 'journalInfo' in subset and 'journal' in subset['journalInfo'] and 'issn' in subset['journalInfo']['journal'] else "NA"

			isopenaccess = subset['isOpenAccess'] if 'isOpenAccess' in subset else "NA"

			pmcid =subset['pmcid'] if 'pmcid' in subset else "NA"
			doi = subset['doi'] if 'doi' in subset else "NA" 
			author = subset["authorList"]["author"] if 'authorList' in subset else "NA"
			affiliation = subset['affiliation'] if 'affiliation' in subset  else "NA" 
			fullname = [d['fullName'] if 'fullName' in d  else "NA" for d in author]
			orcid = [d['authorId']['value'] if 'authorId' in d  else "NA" for d in author]
			pubdate = subset['firstPublicationDate'] if 'firstPublicationDate' in subset  else "NA" 
			epubdate = subset['electronicPublicationDate'] if 'electronicPublicationDate' in subset  else "NA"
			receiptdate = subset['fullTextReceivedDate'] if 'fullTextReceivedDate' in subset  else "NA"
			revisiondate = subset['dateOfRevision'] if 'dateOfRevision' in subset  else "NA"
			
			title = subset['title'] if 'title' in subset else "NA"
			abstract = subset['abstractText'] if 'abstractText' in subset else "NA"
			language = subset['language'] if 'language' in subset else "NA" 
			grantlist = subset['grantsList']['grant'] if 'grantsList' in subset else "NA"
			grantid = [d['grantId'] if 'grantId' in d  else "NA" for d in grantlist]
			grantagency = [d['agency'] if 'agency' in d  else "NA" for d in grantlist]
			grantacronym = [d['acronym'] if 'acronym' in d  else "NA" for d in grantlist]
			keywords = subset["keywordList"]["keyword"] if 'keywordList' in subset else "NA"
			for j,name in enumerate(fullname):
				country=affiliation.split(',')[-1].replace('.','')
				if (re.search(r"(\w+) ([\w.-]+@[\w.-]+.\w+)",country)):
					match=re.search(r"(\w+) ([\w.-]+@[\w.-]+.\w+)",country)
					etat = match.group(1)
				else:
					etat=country
				print("\t".join([accession, _id, source, "|".join(pubtype), jissn + ',' + jessn , isopenaccess,  pmid, pmcid, doi, fullname[j], affiliation, etat, pubdate, epubdate, orcid[j],
					title, abstract, language, ":".join(grantid), ":".join(grantagency), ":".join(grantacronym),
					receiptdate, revisiondate , ", ".join(list(filter(None,keywords)))]))
	elif hitcount == 0:
		print ("No hit found for {}".format(accession))


if __name__=="__main__":
	ap = argparse.ArgumentParser()
	ap.add_argument("-a", "--accession_list", required=True, type=str,
        	help="File containing accession one per line")
	args = vars(ap.parse_args())

	with open (args["accession"]) as acc:
		for cnt,line in enumerate(acc):
			line =line.strip()
			if line:
				curl_it(line)
				time.sleep(2)


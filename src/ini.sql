CREATE TABLE repositories (  -- the JATS Open Access repositories
  repo_id serial PRIMARY KEY,
  repo_abbrev varchar(32),
  repo_name text,
  repo_url text,
  UNIQUE(repo_abbrev),
  UNIQUE(repo_name),
  UNIQUE(repo_url)
);
INSERT INTO repositories (repo_abbrev,repo_name,repo_url) VALUES
 ('scielo-br','SciELO Brasil','http://www.scielo.br'),       -- 1
 ('scielo-ar','SciELO Argentina','http://www.scielo.ar'),    -- 2
 ('pmc','PubMed Central','http://www.ncbi.nlm.nih.gov/pmc/'),-- 3
 ('europepmc','Europe PubMed Central','http://europepmc.org')-- 4
;

CREATE TABLE articles (
  id serial PRIMARY KEY,
  repo int NOT NULL REFERENCES repositorio(id),
  repos_pid varchar(32),   -- repository's public ID
  content_dtd varchar(256),   -- DOCTYPE string (when occurs)
  xcontent xml NOT NULL,  -- JATS full text or front-back data
  info json,    -- formulario dados postados pelos 
  kx json,      -- cache de dados 
  info_modified date, -- data que atualizou o j 
  UNIQUE (repos_pid)
);

CREATE VIEW articles_kxvals AS -- all frequently used metadata or countings 
  SELECT articles.*, repo_abbrev, repo_url,
        substring(repos_pid,2,9) as issn ,
	(xpath('/article/@article-type', xcontent))[1]::text as article_type,
	(xpath('/article/front/journal-meta/journal-id[@journal-id-type="publisher-id"]/text()', xcontent))[1]::text as jou_acronimo,
	(xpath('/article/front/article-meta/article-id[@pub-id-type="doi"]/text()', xcontent))[1]::text as doi,
	array_to_string( (xpath('/article/front//article-title/text()', xcontent))::text[], ' ', ' ') as article_title,
	(xpath('//permissions/license/@n:href', xcontent,'{{n,http://www.w3.org/1999/xlink}}'))[1]::text as license_url,
	array_to_string( (xpath('/article/back//ref//text()', xcontent))::text[], ' ', ' ') as article_refs	
  FROM articles INNER JOIN repositories r ON r.repo_id=articles.repo;

--
-- Cache refresh of all rows, a row by id1, or a range of rows by id1,id2.
--
CREATE FUNCTION articles_kx_refresh(int DEFAULT NULL, int DEFAULT NULL) 
RETURNS void AS $script$
	UPDATE articles  -- article's cache
	SET kx = ('{'
		||  '"repo_abbrev":"'|| repo_abbrev  ||'"'
		||', "issn":"'|| issn  ||'"'
		||', "jou_acronimo":' ||to_json(jou_acronimo)
		||', "doi": "'|| doi ||'"'
		||', "article_type":'  ||to_json(article_type)
		||', "article_title":' ||to_json(article_title)
		||', "license_url":' ||to_json(license_url)
		|| '}')::JSON
	FROM articles_kxvals as k
	WHERE k.id=articles.id AND ( $1 IS NULL OR ($2 IS NULL AND k.id=$1) OR (k.id>=$1 AND k.id<=$2) );
$script$ LANGUAGE sql;


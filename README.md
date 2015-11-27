# giaia-compilacao
Apoio do [hackday do CienciaAberta2015](https://pt.wikiversity.org/wiki/Ci%C3%AAncia_Aberta_2015/Hackday,_sugest%C3%B5es) ao [GIAIA](http://giaia.eco.br/) nos trabalhos de [compilacao](http://giaia.eco.br/compilacao-de-informacoes-e-dados-publicados/), organizando e eextraindo informações de artigos e dados cientificos [JATS](https://en.wikipedia.org/wiki/Journal_Article_Tag_Suite).

'''sql
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
  content_dtd text(256),   -- DOCTYPE string (when occurs)
  content xml NOT NULL,  -- JATS full text or front-back data
  info json,    -- formulario dados postados pelos 
  kx json,      -- cache de dados 
  info_modified date, -- data que atualizou o j 
  UNIQUE (repos_pid)
);

CREATE VIEW articles_kxvals AS -- all frequently used metadata or countings 
  SELECT articles.*, repo_abbrev, repo_url,
        substring(pid,2,9) as issn ,
	(xpath('/article/@article-type', conteudo))[1]::text as article_type,
	(xpath('/article/front/journal-meta/journal-id[@journal-id-type="publisher-id"]/text()', conteudo))[1]::text as jou_acronimo,
	(xpath('/article/front/article-meta/article-id[@pub-id-type="doi"]/text()', conteudo))[1]::text as doi,
	array_to_string( (xpath('/article/front//article-title/text()', conteudo))::text[], ' ', ' ') as article_title,
	(xpath('//permissions/license/@n:href', conteudo,'{{n,http://www.w3.org/1999/xlink}}'))[1]::text as license_url,
	array_to_string( (xpath('/article/back//ref//text()', conteudo))::text[], ' ', ' ') as article_refs	
  FROM articles INNER JOIN repositories r ON r.repo_id=articles.repo;

--
-- Cache refresh of all rows, a row by id1, or a range of rows by id1,id2.
--
CREATE FUNCTION articles_kx_refresh(int DEFAULT NULL, int DEFAULT NULL) 
RETURNS void AS $script$
	UPDATE articles  -- article's cache
	SET kx = ('{'
		||  '"repo_abbrev":"'|| repo_abbrev  ||'"'
		||  '"issn":"'|| issn  ||'"'
		||', "jou_acronimo":' ||to_json(jou_acronimo)
		||', "doi": "'|| doi ||'"'
		||', "article_type":'  ||to_json(article_type)
		||', "article_title":' ||to_json(article_title)
		||', "license_url":' ||to_json(license_url)
		|| '}')::JSON
	FROM articles_kxvals as k
	WHERE k.id=articles.id AND ( $1 IS NULL OR ($2 IS NULL AND k.id=$1) OR (k.id>=$1 AND k.id<=$2) );
$script$ LANGUAGE plpgsql;

```

## Contexto, participantes e andamentos

Participaram da realização do projeto Bruno, Cristina, Gustavo, Letícia e Peter. Optou-se pelo apoio ao GIAIA e pelo entendimento de que a recuperação de informações de artigos científicos permitem compor uma "fotografia do passado recente", subsidiando provas e argumentos jurídicos para a avaliação precisa dos impactos sociais, ambientais e econômicos causados pelo desastre.

A equipe foi dividida em dois grupos, programadores (Peter e Gustavo) e analistas (Bruno, Cristina, Letícia).

Para apoio na familiarização dos participantes com o JATS, foi trazido uma amostra de ~2mil artigos XML de ISSNs que continham algumas amostras de artigos pertinentes. 

## Metodologia na recuperação da informação
A equipe de analistas chegou na seguinte proposta metodológica.

 1. Prospecção-1: pesquisa subjetiva, para avaliar relevância e jargão, sem compromisso com a obtenção de dados em artigos JATS.

 2. Prospecção-2: recuperação de artigos científicos nos repositórios propospos, mas ainda sem com a disponibilidade e condições dos dados ou do JATS dos artigos.

 3. Levantamento JATS: analise dentro do documento.

Para a prospecção-2 foram experimentados o uso do [search.scielo.org](http://search.scielo.org/) e do Google com diretiva `site:scielo.br`. 

Os resultados da prospecção-2 foram registrados em uma planilha, disponibilizada como [fontes_prospec.csv](data/fontes_prospec.csv). Os campos `DOI` e `URL` garantem a identificação do artigo, o campo `issn` foi usado para identificar revistas disponiveis no banco de dados de amostras XML JATS, e os campos `area` e `coments` para uma categorização preliminar, conforme os objetivos do projeto. Os campos `busca` e `dado` referem-se a elementos da estrutura JATS ou XHTML, onde os dados relevantes do artigo podem ser encontrados.


## Software
Optou-se pelo uso de uma linguagem que a maioria dos participantes conhece, o Python. Posteriormente foi sugerido compor algoritmos básicos em duas versões, Python e PHP, ampliando o potencial de replicação e colaboração.

A concepção do software envolveu *concepção de modelo de dados*, *escolha das ferramentas* (entre file system em SGBD, optou-se pelo SGMBD PostgreSQL 9.3+ que lida com XML e JSON), e *formulação dos algoritmos básicos*:

* **Carga**: no loop de carga optou-se por usar [*prepared statements*](http://php.net/manual/pt_BR/pdo.prepared-statements.php), e não fazer nenhuma análise prévia sobre o XML. 

* **Análise**: a recuperação das informações relevantes pode envolver tanto a "filtragem" de grandes quantidades de registros, no que optou-se por manter os metadados desses filtros em cache (ver `kx` JSON), como a pesquisa em elementos específicos do documento. A principal hipótese de trabalho é que esse tipo de pesquisa, sobre elementos escolhidos e não sobre o texto integral do artigo, pode oferecer maior potencial de [precisão e revogação](https://en.wikipedia.org/wiki/Precision_and_recall).

## Indexação final 

Inspirados no mapa do [caminho dos rejeitos](https://www.google.com/maps/d/viewer?mid=z2hz1UsCLzkQ.kL9XhcKkN7u4), foi proposta a indexação mais detalhada da relação dos dados e conclusões relevantes do artigo científico com a entidade geográfico onde as observações foram realizadas. Entidades previstas (todas existentes ou passíveis de delimitação no OpenStreetMaps):

 * Município:  polígono dos limites do município. Exemplo: [Mariana](https://pt.wikipedia.org/wiki/Mariana).

 * Distrito/subdistrito:  polígono dos limites do distrito de um município. Exemplo: [Bento Rodrigues](https://pt.wikipedia.org/wiki/Bento_Rodrigues).

 * Bacia hidrográfica: bacia ou microbacia conforme denominação FEHIDRO. Exemplo [Bacia do Rio Doce](https://pt.wikipedia.org/wiki/Bacia_do_rio_Doce).

 * Rio: linha central da área média ocupação das águas de um rio (rios, riachos, etc.). 

 * Estrada. 

 * Outras denominações: [Mesorregião do Vale do Rio Doce](https://pt.wikipedia.org/wiki/Mesorregi%C3%A3o_do_Vale_do_Rio_Doce).

## ...

... Em construção! ...




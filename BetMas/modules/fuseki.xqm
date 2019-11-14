xquery version "3.1" encoding "UTF-8";
module namespace fusekisparql = 'https://www.betamasaheft.uni-hamburg.de/BetMas/sparqlfuseki';
import module namespace config = "https://www.betamasaheft.uni-hamburg.de/BetMas/config" at "xmldb:exist:///db/apps/BetMas/modules/config.xqm";

declare namespace t = "http://www.tei-c.org/ns/1.0";
declare namespace http = "http://expath.org/ns/http-client";

(:Assumes that Fuseki is running in Tomcat, and that Tomcat server.xml has been edited to run on port 8081, instead of 8080. :)
declare variable $fusekisparql:port := 'http://localhost:8081/fuseki/';


(:~ given a SPARQL query this will pass it to the selected dataset  and return SPARQL Results in XML:)
declare function fusekisparql:query($dataset, $query) {
    let $url := concat($fusekisparql:port||$dataset||'/query?query=', encode-for-uri($query))
    (:   here the format of the response could be set:)
    let $headers := <Headers/>
    let $file := httpclient:get(xs:anyURI($url), true(), $headers)
    return
        $file
};

(:~ given a SPARQL Update input for the type of operation (INSERT or DELETE),  the triples to be added in the SPARQL Update and the destination
dataset, this function will send a POST request to the location of a running Fuseki instance and perform the operation:)
declare function fusekisparql:update($dataset, $InsertOrDelete, $triples) {
    let $url := $fusekisparql:port||$dataset||'/update'
    let $sparqlupdate := $config:sparqlPrefixes || $InsertOrDelete || ' DATA
{ 
  '||$triples||'
}'
    let $req :=
    <http:request
        http-version="1.1"
        href="{xs:anyURI($url)}"
        method="POST">
        <http:header
            name="Content-type"
            value="application/sparql-update"></http:header>
        <http:body
            media-type="text/plain">{$sparqlupdate}</http:body>
    </http:request>
    let $post := hc:send-request($req)[2]
    return
        $post
};
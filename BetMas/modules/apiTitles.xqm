xquery version "3.1" encoding "UTF-8";
(:~
 : titles from API
 : 
 : @author Pietro Liuzzo 
 :)
 
module namespace apiTit = "https://www.betamasaheft.uni-hamburg.de/BetMas/apiTitles";
import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace api = "https://www.betamasaheft.uni-hamburg.de/BetMas/api"  at "xmldb:exist:///db/apps/BetMas/modules/rest.xqm";
import module namespace all="https://www.betamasaheft.uni-hamburg.de/BetMas/all" at "xmldb:exist:///db/apps/BetMas/modules/all.xqm";
import module namespace log="http://www.betamasaheft.eu/log" at "xmldb:exist:///db/apps/BetMas/modules/log.xqm";
import module namespace titles="https://www.betamasaheft.uni-hamburg.de/BetMas/titles" at "xmldb:exist:///db/apps/BetMas/modules/titles.xqm";
import module namespace config = "https://www.betamasaheft.uni-hamburg.de/BetMas/config" at "xmldb:exist:///db/apps/BetMas/modules/config.xqm";
(: namespaces of data used :)
declare namespace t = "http://www.tei-c.org/ns/1.0";
import module namespace http="http://expath.org/ns/http-client";

declare namespace test="http://exist-db.org/xquery/xqsuite";

(: For REST annotations :)
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $apiTit:TUList := doc(concat($config:app-root, '/lists/textpartstitles.xml'));

(:~ given the file id, returns the main title:)
declare
%rest:GET
%rest:path("/BetMas/api/{$id}/title")
%output:method("text")
function apiTit:get-FormattedTitle($id as xs:string) {
    ($config:response200,
    let $id := replace($id, '_', ':') 
    
    return
    if (not(contains($id, ':'))) then
   normalize-space(string-join(titles:printTitleMainID($id)))
   else if (starts-with($id, 'wd:') or starts-with($id, 'pleaides:') or starts-with($id, 'sdc:') or starts-with($id, 'gn:')   )
   then
   normalize-space(titles:printTitleMainID($id))
    else $id
    )
};


(:~ given the file id and an anchor, returns the formatted main title and the title of the reffered section:)
declare
%rest:GET
%rest:path("/BetMas/api/{$id}/{$SUBid}/title")
%output:method("text")
function apiTit:get-FormattedTitleandID($id as xs:string, $SUBid as xs:string) {
    ($config:response200, 
    let $fullid := ($id||'#'||$SUBid)
    return
    if ($apiTit:TUList//t:item[@corresp = $fullid]) then ($apiTit:TUList//t:item[@corresp = $fullid]/node()) else (
    titles:printTitleID($fullid)    
    )
    )
};

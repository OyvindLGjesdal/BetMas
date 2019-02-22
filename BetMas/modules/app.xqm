xquery version "3.1" encoding "UTF-8";
(:~
 : module used by the app for string query, templating pages and general behaviours
 : mostly inherited from exist-db examples app but all largely modified
 : 
 : @author Pietro Liuzzo <pietro.liuzzo@uni-hamburg.de'>
 :)
module namespace app="https://www.betamasaheft.uni-hamburg.de/BetMas/app";

declare namespace test="http://exist-db.org/xquery/xqsuite";
declare namespace t="http://www.tei-c.org/ns/1.0";
declare namespace functx = "http://www.functx.com";
declare namespace exist = "http://exist.sourceforge.net/NS/exist";
declare namespace skos = "http://www.w3.org/2004/02/skos/core#";
declare namespace rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace s = "http://www.w3.org/2005/xpath-functions";
declare namespace sr = "http://www.w3.org/2005/sparql-results#";

import module namespace switch = "https://www.betamasaheft.uni-hamburg.de/BetMas/switch"  at "xmldb:exist:///db/apps/BetMas/modules/switch.xqm";
import module namespace kwic = "http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace log="http://www.betamasaheft.eu/log" at "xmldb:exist:///db/apps/BetMas/modules/log.xqm";
import module namespace coord="https://www.betamasaheft.uni-hamburg.de/BetMas/coord" at "xmldb:exist:///db/apps/BetMas/modules/coordinates.xql";
import module namespace nav="https://www.betamasaheft.uni-hamburg.de/BetMas/nav" at "xmldb:exist:///db/apps/BetMas/modules/nav.xqm";
import module namespace ann = "https://www.betamasaheft.uni-hamburg.de/BetMas/ann" at "xmldb:exist:///db/apps/BetMas/modules/annotations.xql";
import module namespace all="https://www.betamasaheft.uni-hamburg.de/BetMas/all" at "xmldb:exist:///db/apps/BetMas/modules/all.xqm";
import module namespace editors="https://www.betamasaheft.uni-hamburg.de/BetMas/editors" at "xmldb:exist:///db/apps/BetMas/modules/editors.xqm";
import module namespace titles="https://www.betamasaheft.uni-hamburg.de/BetMas/titles" at "xmldb:exist:///db/apps/BetMas/modules/titles.xqm";
import module namespace config="https://www.betamasaheft.uni-hamburg.de/BetMas/config" at "xmldb:exist:///db/apps/BetMas/modules/config.xqm";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace validation = "http://exist-db.org/xquery/validation";
import module namespace sparql="http://exist-db.org/xquery/sparql" at "java:org.exist.xquery.modules.rdf.SparqlModule";
import module namespace console="http://exist-db.org/xquery/console";

(:~declare variable $app:item-uri as xs:string := raequest:get-parameter('uri',());:)
declare variable $app:collection as xs:string := request:get-parameter('collection',());
declare variable $app:name as xs:string := request:get-parameter('name',());
declare variable $app:rest  as xs:string := '/rest/';
declare variable $app:languages := doc('/db/apps/BetMas/languages.xml');
declare variable $app:range-lookup := 
    (
        function-lookup(xs:QName("range:index-keys-for-field"), 4),
        function-lookup(xs:QName("range:index-keys-for-field"), 3)
    )[1];
    
    declare variable $app:util-index-lookup := 
    (
        function-lookup(xs:QName("util:index-keys"), 5),
        function-lookup(xs:QName("util:index-keys"), 4)
    )[1];
    
(:~collects bibliographical information for zotero metadata:)
declare variable $app:bibdata := 
let $file := $config:collection-root/id($app:name)
let $auths := $file//t:revisionDesc/t:change/@who[. != 'PL']
return

(:~here I cannot use for the title the javascript titles.js because the content is not exposed:)
<bibl>
{
for $author in distinct-values($auths)
let $count := count($file//t:revisionDesc/t:change[@who = $author])
order by $count descending
                return
<author>{editors:editorKey(string($author))}</author>
}
<title level="a">{titles:printTitle($file)}</title>
<title level="j">{$config:collection-root/id($app:name)//t:publisher/text()}</title>
<date type="accessed"> [Accessed: {current-date()}] </date>
{let $time := max($file//t:revisionDesc/t:change/xs:date(@when))
return
<date type="lastModified">(Last Modified: {format-date($time, '[D].[M].[Y]')}) </date>
}
<idno type="url">
{($config:appUrl || $app:collection||'/' ||$app:name)}
</idno>
<idno type="DOI">
{($config:DOI || '.' ||$app:name)}
</idno>
</bibl>
;


declare variable $app:search-title as xs:string := "Search: ";
declare variable $app:searchphrase as xs:string := request:get-parameter('query',());
declare variable $app:APP_ROOT :=
    let $nginx-request-uri := request:get-header('nginx-request-uri')
    return
        (: if request received from nginx :)
        if ($nginx-request-uri) then
                ""
        (: otherwise we're in the eXist URL space :)
        else
            request:get-context-path() || "/apps/BetMas"
            ;


declare function app:interpretationSegments($node as node(), $model as map(*)){
 for $d in distinct-values($config:collection-rootMS//t:seg/@ana)
                    return
                    <option value="{$d}">{substring-after($d, '#')}</option>
                    };


(:get parallel diplomatique forms:)
declare function app:diplomatiqueforms($node as node(), $model as map(*),$interpret as xs:string*)
{
let $path := '$config:collection-root//t:seg[@ana="' || $interpret ||'"]'
let $hits := for $occurrence in util:eval($path)
                 return $occurrence
return
map {'hits':=$hits}
};

declare 
%templates:wrap
    %templates:default('start', 1)
    %templates:default("per-page", 10) 
function app:diplomatiqueResults($node as node(), 
    $model as map(*), $start as xs:integer, $per-page as xs:integer) {
        
    for $occurrence at $p in subsequence($model("hits"), $start, $per-page)
let $text := normalize-space($occurrence/text())
let $rootID := string(root($occurrence)/t:TEI/@xml:id)
let $itemid := string($occurrence/ancestor::t:item/@xml:id)
let $source := ($rootID || '#' || $itemid)
let $stitle := $source
return 
<div class="row reference">
                <div class="col-md-1"><span class="number">{$start + $p - 1}</span></div>
                        <div class="col-md-3"><a href="/{$rootID}">{titles:printTitleID($rootID)}</a> ({$rootID}#{$itemid})</div>
                        <div class="col-md-8">{$text}</div>
                        
                    </div>

};

(:~ logging function to be called from templating pages:)
declare function app:logging ($node as node(), $model as map(*)){
let $url := request:get-uri()
 let $parameterslist := request:get-parameter-names()
   let $paramstobelogged := for $p in $parameterslist for $value in request:get-parameter($p, ()) return ($p || '=' || $value)
   let $logparams := if(count($paramstobelogged) >= 1) then '?' || string-join($paramstobelogged, '&amp;') else ()
   let $url := $url || $logparams
   return 
   log:add-log-message($url, xmldb:get-current-user(), 'page')
  
};


(:~storing separately this input in this 
 : function makes sure that when the page is 
 : reloaded with the results the value entered remains in the input element:)
declare function app:queryinput ($node as node(), $model as map(*), $query as xs:string*){<input name="query" type="search" class="form-control diacritics" placeholder="type here the text you want to search" value="{$query}"/>};

(: ~
 : the PDF link html snippet, called by other function based on if statements :)
declare function app:pdf-link($id) {
    
        <a  xmlns="http://www.w3.org/1999/xhtml" id="mainPDF" href="/{$id}.pdf" class="btn btn-info"><i class="fa fa-file-pdf-o" aria-hidden="true"></i></a>
};


(: ~ calls the templates for static parts of the page so that different templates can use them. To make those usable also from restxq, they have to be called by templates like this, so nav.xql needs not the template module :)
declare function app:Nbar($node as node()*, $model as map(*)){nav:bar()};
 declare function app:searchhelp($node as node()*, $model as map(*)){nav:searchhelp()};
declare function app:modals($node as node()*, $model as map(*)){nav:modals()};
declare function app:footer($node as node()*, $model as map(*)){nav:footer()};



(:~  returns a responsive table with a list of the collection selected by parameter. 
 : The parameter is decided by the url call, which is handled by the controller. 
 : might be better as a proper view. :)
declare 
%templates:wrap %templates:default('start', 1) %templates:default("per-page", 20) 
function app:table($model as map(*), $start as xs:integer, $per-page as xs:integer) {
     let $items-info := $model('hits')
     let $collection := $model('collection')
return
<table class="table table-hover table-responsive">
                    <thead data-hint="The color of each row tells you about the status of the entry. red is a stub, yellow is in progress, green/blue is completed.">
                        <tr>{
            if ($collection = 'works') then
                (<th>n°</th>,
                            <th>Titles</th>,
                            <th>Authors</th>,
                            <th>Witnesses</th>,
                            <th>Main parts</th>,
                            <th>Text</th>
                            )
            else
                if ($collection = 'places') then
                    (<th>Name</th>,
                                <th>wikidata</th>,
                                <th>geoJson</th>)
                else
                    if ($collection = 'institutions') then
                        (<th>Name</th>,
                                    <th>Mss</th>,
                                <th>wikidata</th>,
                                    <th>geoJson</th>)
                    else
                        if ($collection = 'persons') then
                            (<th>Name</th>,
                                        <th>Wikidata</th>,
                                        <th>Gender</th>,
                                        <th>Occupation</th>)
                        else
                            if ($collection = 'narratives') then
                                (<th>Name</th>,
                                            <th>Text</th>)
 else
                            if ($collection = 'authority-files') then
                                (<th>Name</th>)
else
                                (<th>Name</th>,
                                            <th>Shelfmarks</th>,
                                            <th>Images</th>,
                                            <th>Textual Units</th>,
                                            <th>Manuscript Parts</th>,
                                            <th>Hands</th>,
                                            <th>Script</th>,
                                      <th data-hint="select the manuscripts you want to compare and click the button above to go to the comparison view.">Compare</th>,
                                            <th>Text</th>)
        }
                            <th>Dated</th>
                            <th>TEI-XML</th>
                            <th>Analytics</th>
                            <th>Print</th>
    </tr>
                    </thead>
                   <tbody  class="ListItems">
                                        {
                                    for $hit at $p in subsequence($items-info, $start, $per-page)
                                   let $doc := doc(base-uri($hit))
            return
                                                   app:tr($doc, $collection)
                               
                             
                                    }
                                    </tbody>
                </table>
};


(:~table rows and color code for change records:)
declare function app:tr($doc as node(), $list as xs:string) {

    <tr class="ListItems"
        style="{
                if (count($doc//t:change[@who != 'PL']) eq 1) then
                    'background-color:#ffefcc;'
                else
                    if ($doc//t:change[contains(., 'completed')]) then
                        'background-color:#e6ffff;'
                    else
                        if ($doc//t:change[contains(., 'reviewed')]) then
                            'background-color:#e6ffe6;'
                        else
                            'background-color:#ffe6e6;'
            }">
            
            {
            
            
           app:tds($doc, $list)
            
            }
       
    </tr>
    
};

(:~function to print the values of parallel clavis ids:)
declare function app:clavisIds($doc as node()){
    <p class="lead"><span class="badge badge-dark">CAe {substring(string($doc/@xml:id), 4, 4)}</span></p>,
if($doc//t:listBibl[@type='clavis']) 
            then (
            <table class="table table-hover table-responsive">
            <thead>
            <tr>
            <th>clavis</th><th>id</th></tr>
            </thead>
            <tbody>
            {for $bibl in $doc//t:listBibl[@type='clavis']/t:bibl 
            return 
            <tr>
            <td>
            {string($bibl/@type) }
            </td>
            <td>
            <a href='{$bibl/@corresp}'>{$bibl/t:citedRange/text()}{if($bibl/ancestor::t:div[@type='textpart' or @type='edition']) then (' (' || string($bibl/ancestor::t:div[@type][1]/@xml:id) || ')') else ()}</a>
            </td>
            </tr>
            }
            </tbody>
            </table>
            ) else ()
};


(:~table cells:)
declare function app:tds($item as node(), $list as xs:string) {

let $itemid := string($item/t:TEI/@xml:id)
let $itemtitle := titles:printTitleID($itemid)
   
return

(
if ($list = 'works') then (
(: id only works :)
<td><a
            href="/{$list}/{$itemid}/main">{if(ends-with($itemid, 'IHA'))  then ('IslHornAfr ' || substring($itemid, 4, 4)) else ('CAe ' || substring($itemid, 4, 4))}</a>
            {app:clavisIds($item)}
            </td>)
            else if ( matches($list, '\w+\d+\w+'))then (
(: link to main view from catalogues :)
<td><a
            href="/manuscripts/{$itemid}/main">{$itemtitle}</a>
            </td>) 
            else if ( starts-with($list, 'INS'))then (
(: link to list view for institutions :)
<td><a
            href="/manuscripts/{$itemid}/main">{$itemtitle}</a>
            </td>) 
            else if ($list = 'institutions') then (
(: link to list view for institutions :)
<td><a
            href="/manuscripts/{$itemid}/list">{$itemtitle}</a>
            </td>) 
    else
    (:  name ALL:)
        (<td><a
            href="/{$itemid}" >{$itemtitle}</a></td>),
            
            
    if ($list = 'works') then
        (
   (:work titles:)
        <td><ul class="nodot">
                {
                    for $title in $item//t:titleStmt/t:title
                    return
                        <li>{$title/text()} {if ($title/@xml:lang) then (' (' || string($title/@xml:lang) || ')') else ()}</li>
                }
            </ul>
        </td>,
(:        work authors:)
        <td><ul class="nodot">
                {
                    for $author in $item//t:titleStmt/t:author
                    return
                        <li>{$author}</li>
                }
                {
                let $attributions := for $r in $item//t:relation[@name="saws:isAttributedToAuthor"]
                let $rpass := $r/@passive
                return 
                if (contains($rpass, ' ')) then tokenize($rpass, ' ') else $rpass
                    for $author in distinct-values($attributions)
                    return
                        <li><a href="{$author}"><mark>{try{titles:printTitleID($author)} catch*{$author//t:titleStmt/t:title[1]/text()}}</mark></a></li>
                }
            </ul>
        </td>,
(:        work witnesses:)
        <td>
            <ul  class="nodot">
                {
                    for $witness in $item//t:listWit/t:witness
                    let $corr := $witness/@corresp
                    return
                        <li><a
                                href="{$witness/@corresp}" class="MainTitle"  data-value="{$corr}" >{string($corr)}</a></li>
                }
            </ul>
            <ul  class="nodot">
                {
                    for $parallel in $config:collection-root//t:relation[@name='saws:isVersionOf'][contains(@passive, $itemid)]
                    let $p := $parallel/@active
                    return
                        <li><a
                                href="{$p}" class="MainTitle"  data-value="{$p}" >{$p}</a></li>
                }
            </ul>
            <ul  class="nodot">
                {
                    for $parallel in $config:collection-root//t:relation[@name='isVersionInAnotherLanguageOf'][contains(@passive, $itemid)]
                     let $p := $parallel/@active
                    return
                        <li><a
                                href="{$p}" class="MainTitle"  data-value="{$p}" >{$p}</a></li>
                }
            </ul>
            <a role="button" class="btn btn-primary btn-xs" href="/compare?workid={$itemid}">compare</a>
        </td>,
(:        work parts:)
        <td class="textparts">
            <ul  class="nodot">
              
            </ul>
        </td>)
    else
        if ($list = 'manuscripts' or starts-with($list, 'INS')  or matches($list, '\w+\d+\w+')) then
        
(:      images  msitemsm msparts, hands, script:)
            (<td>{let $idnos := for $shelfmark in $item//t:msIdentifier//t:idno return $shelfmark/text() return string-join($idnos, ', ')}
            </td>,
            <td>{if ($item//t:facsimile/t:graphic/@url) then <a target="_blank" href="{$item//t:facsimile/t:graphic/@url}">Link to images</a> else if($item//t:msIdentifier/t:idno/@facs) then 
                 <a target="_blank" href="/manuscripts/{$itemid}/viewer">{
                if($item//t:collection = 'Ethio-SPaRe') 
               then <img src="{$config:appUrl ||'/iiif/' || string($item//t:msIdentifier/t:idno/@facs) || '_001.tif/full/80,100/0/default.jpg'}" class="thumb"/>
(:laurenziana:)
else  if($item//t:repository/@ref[.='INS0339BML']) 
               then <img src="{$config:appUrl ||'/iiif/' || string($item//t:msIdentifier/t:idno/@facs) || '005.tif/full/80,100/0/default.jpg'}" class="thumb"/>
          
(:          
EMIP:)
              else if($item//t:collection = 'EMIP' and $item//t:msIdentifier/t:idno/@n) 
               then <img src="{$config:appUrl ||'/iiif/' || string($item//t:msIdentifier/t:idno/@facs) || '001.tif/full/80,100/0/default.jpg'}" class="thumb"/>
              
             (:BNF:)
            else if ($item//t:repository/@ref = 'INS0303BNF') 
            then <img src="{replace($item//t:msIdentifier/t:idno/@facs, 'ark:', 'iiif/ark:') || '/f1/full/80,100/0/native.jpg'}" class="thumb"/>
(:           vatican :)
                else <img src="{replace(substring-before($item//t:msIdentifier/t:idno/@facs, '/manifest.json'), 'iiif', 'pub/digit') || '/thumb/'
                    ||
                    substring-before(substring-after($item//t:msIdentifier/t:idno/@facs, 'MSS_'), '/manifest.json') || 
                    '_0001.tif.jpg'
                }" class="thumb"/>
                 }</a>
                
                else ()}</td>,
            <td>{count($item//t:msItem[not(t:msItem)])}</td>,
            <td>{
                    if (count($item//t:msPart) = 0) then
                        1
                    else
                        count($item//t:msPart)
                }{
                    if ($item//t:collation[descendant::t:item]) then
                        ' with collation'
                    else
                        ()
                }</td>,
            <td>{count($item//t:handNote)}</td>,
            <td>{distinct-values(data($item//@script))}</td>,
<td><input type="checkbox" class="form-control compareSelected" data-value="{$itemid}"/></td>
            )
        else
            if ($list = 'persons') then
(:            gender:)
                (
                <td>{let $wd :=string($item//t:person/@sameAs)
                return
                <a
                    href="{('https://www.wikidata.org/wiki/'||$wd)}"
                    target="_blank">{$wd}</a>}</td>,
                <td>{
                    switch (data($item//t:person/@sex))
                            case "1"
                                return
                                    <i class="fa fa-male" aria-hidden="true"></i>
                            case "2"
                                return
                                   <i class="fa fa-female" aria-hidden="true"></i>
                            default return
                                ()
                }</td>,
                <td>{
                   let $occupation := $item//t:person/t:occupation
                           return 
                           $occupation/text()
                }</td>
            )
        else
            if ($list = 'institutions') then
(:            mss from same repo:)
                (
                <td>{
                        let $id := string($itemid)
                        let $mss := $config:collection-rootMS//t:repository[@ref = $id]
                        return
                            count($mss)
                    }</td>
                )
            else
                (),  
if ($list = 'places' or $list = 'institutions') then
(:geojson:)
    (<td>{
    let $wd := string($item//t:place/@sameAs)
    return
            if ($wd) then
                <a
                    href="{('https://www.wikidata.org/wiki/'||$wd)}"
                    target="_blank">{$wd}</a>
            else
                ()
        }</td>,
    <td>{
            if ($item//t:geo) then
                <a
                    href="{($itemid)}.json"
                    target="_blank"><span
                        class="glyphicon glyphicon-map-marker"></span></a>
            else
                ()
        }</td>)
else
    if ($list = 'works' or $list = 'manuscripts' or starts-with($list, 'INS') or matches($list, '\w+\d+\w+') or $list = 'narratives') then
  
(:    text:)
        <td>
      {
  if ($item//t:div/t:ab) 
  then
         <a href="{('/' || $itemid || '/text')}"
                        target="_blank">text</a>
            else
                ()
        }
        </td>
else
    (),
    
(:    date, xml, analytics, seeAlso:)
<td>{
        if ($list = 'works' or $list = 'manuscripts' or $list = 'narratives' or $list = 'places' or $list = 'institutions') 
        
        then (
      let $dates :=
           for $date in ($item//t:date[@evidence = 'internal-date'],
        $item//t:origDate[@evidence = 'internal-date'], 
        $item//t:date[@type = 'foundation'], 
        $item//t:creation)
             
           return
          ('['||data($date/ancestor::t:*[@xml:id][1]/@xml:id)|| '] '||
                (if ($date/@when) then
                    data($date/@when)
                     else
                    if ($date/@notBefore or $date/@notAfter) then
                        ('between ' || (if ($date/@notBefore) then data($date/@notBefore) else ('?')) || ' and ' || (if ($date/@notAfter) then data($date/@notAfter) else ('?')))
                else
                    if ($date/@from or $date/@to) then
                        (data($date/@from) || '-' || data($date/@to))
                    else
                        $date))
                        
        return
        string-join($dates, ', ')
            ) 
         else if ($list = 'persons') then (
         if ($item//t:birth[@when or @notBefore or @notAfter or text()[. !='']] or 
        $item//t:death[@when or @notBefore or @notAfter  or text()[. !='']] or 
       $item//t:floruit[@when or @notBefore or @notAfter  or text()[. !='']])
        then(
         for $date in ($item//t:birth[@when or @notBefore or @notAfter or text()], 
         $item//t:death[@when or @notBefore or @notAfter or text()], 
         $item//t:floruit[@when or @notBefore or @notAfter or text()])
        return
        <p>{switch ($date/name())
        case 'birth' return 'b. '
        case 'death' return 'd. '
        default return 'f. ',
            if($date[@when]) 
            then string($date/@when)
            else if($date[@notBefore and @notAfter]) 
            then string($date/@notBefore) || '-'|| string($date/@notAfter)
            else if($date[@notBefore and not(@notAfter)]) 
            then 'after ' || string($date/@notBefore)
            else if($date[@notAfter and not(@notbefore)]) 
            then 'before ' || string($date/@notAfter) 
            else transform:transform($date, 'xmldb:exist:///db/apps/BetMas/xslt/dates.xsl',())  }</p>
           
         )
           else
            'N/A'
        )
        
       
         
            
            else 'N/A'
    }</td>,
<td><a
        href="{('/tei/' || $itemid || '.xml')}"
        target="_blank">XML</a></td>,
<td><a
        href="{( '/' || $itemid || '/analytic')}"
        target="_blank"><span
            class="glyphicon glyphicon-list-alt"></span></a></td>,
<td><input type="checkbox" class="form-control pdf" data-value="{$itemid}"/></td>
)
};


(:~ the new issue button with a link to the github repo issues list :)
declare function app:newissue($node as node()*, $model as map(*)){
<a role="button" class="btn btn-warning btn-xs" target="_blank" href="https://github.com/BetaMasaheft/Documentation/issues/new?title={$app:name}&amp;labels[]={$app:collection}&amp;labels[]=app&amp;assignee=PietroLiuzzo&amp;body=There%20is%20an%20issue%20with%20{$app:name}">new issue</a>};

(:~ button only visible to editors for creating a new entry  :)
declare function app:nextID($collection as xs:string) {
if(contains(sm:get-user-groups(xmldb:get-current-user()), 'Editors')) then (
<a role="button" class="btn btn-primary" target="_blank" href="/newentry.html?collection={$collection}">create new entry</a>) else ()
};

(:~determins what the selectors for various form controls will look like, is called by app:formcontrol() :)
declare function app:selectors($nodeName, $path, $nodes, $type, $context){
             <select multiple="multiple" name="{$nodeName}" id="{$nodeName}" class="form-control">
            {
            
            if ($type = 'keywords') then (
                    for $group in $nodes/t:category[t:desc]
                    let $label := $group/t:desc/text()
                     let $rangeindexname := switch($label) 
                    case 'Occupation' return 'occtype'
                    case 'Art Themes' return 'refcorresp'
                    case 'Additiones' return 'desctype'
                    case 'Place types' return 'placetype'
                    default return 'termkey'
                    return
                    for $n in $group//t:catDesc
                    let $id := $n/text()
                    let $title :=titles:printTitleMainID($id)
                   
                    let $facet := try{
                        $path/$app:range-lookup($rangeindexname, $id, function($key, $count){$count[2]}, 100)} catch*{($err:code || $err:description)}
                    let $fac := if($facet[1] ge 1) then $facet[1] else '0'
                    return
                       <option value="{$id}">{($title[1] ||' (' || $fac  ||')')}</option>
                                )
                                              
            else if ($type = 'name')
                            then (for $n in $nodes[. != ''][. != ' ']
                            let $id := string($n/@xml:id)
                            let $title := titles:printTitleMainID($id)
                                               order by $id
                                               return
            
                                                <option value="{$id}" >{$title}</option>
                                          )
            else if ($type = 'rels')
                     then (
                    
                 for $n in $nodes[. != ''][. != ' ']
                          let $title :=  titles:printTitleID($n)
                            order by $title[1] 
                             return
            
                             <option value="{$n}">{normalize-space(string-join($title))}</option>
                        )
             else if ($type = 'hierels')
             then (
             for $n in $nodes[. != ''][. != ' '][not(starts-with(.,'#'))]
             group by $work := if (contains($n, '#')) then (substring-before($n, '#')) else $n
                            order by $work
                                return 
                                let $label :=
                                    try{
                                        if ($config:collection-root/id($work)) 
                                        then titles:printTitle($config:collection-root/id($work)) 
                                        else $work} 
(:                                        this has to stay because optgroup requires label and this cannot be computed from the javascript as in other places:)
                                    catch* {
                                        ('while trying to create a list for the filter ' ||$nodeName || ' I got '|| $err:code ||': '||$err:description || ' about ' || $work), 
                                         $work}
                                return
                                if (count($n) = 1)
                                then <option value="{$work}" class="MainTitle" data-value="{$work}">{$work}</option>
                                else(
                                      <optgroup label="{$label}">
                  
                    { for $subid in $n
                    return
                                        <option value="{$subid}">{
                                          if (contains($subid, '#')) then substring-after($subid, '#') else 'all'
                                         }</option>
                                         }
                             
                             
                                    </optgroup>)
                                    
                                    )
            else if ($type = 'institutions')
                      then (
                             let $institutions := $config:collection-rootIn//t:TEI/@xml:id
                                 for $institutionId in $nodes[.=$institutions]
                            return
            
                            <option value="{$institutionId}" class="MainTitle" data-value="{$institutionId}">{$institutionId}</option>
                        )
            
            else if ($type = 'sex')
                     then (for $n in $nodes[. != ''][. != ' ']
                        let $key := replace(functx:trim($n), '_', ' ')
                         order by $n
                         return
                             <option value="{string($key)}">{switch($key) case '1' return 'Male' default return 'Female'}</option>
                        )
            else(
            (: type is values :)
            for $n in $nodes[. != ''][. != ' ']
                let $thiskey := replace(functx:trim($n), '_', ' ')
                let $title := if($nodeName = 'keyword' or $nodeName = "placetype"or $nodeName = "country"or $nodeName = "settlement") then titles:printTitleID($thiskey) 
                                        else if ($nodeName = 'language') then $app:languages//t:item[@xml:id=$thiskey]/text()
                                        else $thiskey
                let $rangeindexname := 
                                        switch($nodeName) 
                                        case 'relType' return 'relname' 
                                        case 'language' return 'TEIlanguageIdent' 
                                        case 'material' return 'materialkey' 
                                        case 'bmaterial' return 'materialkey'
                                         case 'placetype' return 'placetype' 
                                         case 'country' return 'countryref' 
                                         case 'settlement' return 'settlref' 
                                         case 'occupation' return 'occtype' 
                                         case 'faith' return 'faithtype' 
                                         case 'objectType' return 'form' 
                                         default return 'termkey'
                 let $ctx := util:eval($context)
                 let $facet := if($nodeName = 'script') 
                                          then ($app:util-index-lookup($ctx//@script, lower-case($thiskey), function($key, $count) {$count[2]}, 100, 'lucene-index' )) 
                                          else ( $ctx/$app:range-lookup($rangeindexname, $thiskey, function($key, $count) {$count[2]}, 100))
                order by $n
                return
                
            <option value="{$thiskey}">{if($thiskey = 'Printedbook') then 'Printed Book' 
             else $title} {(' ('||$facet[1]||')')}</option>
            )
            }
        </select>
};

(:~ builds the form control according to the data specification and is called by all 
 : the functions building the search form. these are in turn called by a html div called by a javascript function.
 : retold from user perspective the initial form in as.html uses the controller template model with the template search.html, which calls 
 : a javascirpt filters.js which on click loads with AJAX the selected form*.html file. 
 : Each of these contains a call to a function app:NAMEofTHEform which will call app:formcontrol which will call app:selectors:)
declare function app:formcontrol($nodeName as xs:string, $path, $group, $type, $context) {

        

if ($group = 'true') 
then ( 
      let $values := for $i in $path return  if (contains($i, ' ')) then tokenize($i, ' ') else if ($i=' ' or $i='' ) then () else functx:trim(normalize-space($i))
      let $nodes := distinct-values($values)
      return 
       <div class="form-group">
                    <label for="{$nodeName}">{$nodeName}s <span class="badge">{count($nodes[. != ''][. != ' '])}</span></label>
                    {app:selectors($nodeName, $path, $nodes, $type, $context) }
      </div>
      )
else (
         let $nodes := for $node in $path return $node
            return
       app:selectors($nodeName, $path, $nodes, $type, $context)   
       )
};



(:~the filters available in the search results view used by search.html:)
declare function app:searchFilter($node as node()*, $model as map(*)) {
let $items-info := $model('hits')
let $q := $model('q')
let $cont := $model('query')
return

<form action="" class="form form-horizontal">
                {app:formcontrol('language', $items-info//@xml:lang, 'true', 'values', $cont),
                app:formcontrol('keyword', $items-info//t:term/@key, 'true', 'titles', $cont),
               
                <div class="form-group container">
                <label for="dates">date range</label>
                <div class="input-group">
                <input id="dates" type="text" class="span2" 
                name="dateRange" 
                data-slider-min="0" 
                data-slider-max="2000" 
                data-slider-step="10" 
                data-slider-value="[0,2000]"/>
                <script type="text/javascript">
                {"$('#dates').bootstrapSlider({});"}
                </script>
            </div>
            </div>,
            <div>
  <input type="hidden" name="query" value="{$q}"/></div>
            }
                <button type="submit" class="btn btn-primary"> Filter
                    </button>
                <a href="/as.html" role="button" class="btn btn-primary">Advanced Search Form</a>
</form>
};


(:~query parameters and corresponding filtering of the xpath context for ft:query
 : returns xpath as string to be later evaluated:)
declare function app:ListQueryParam($parameter, $context, $mode, $function){
let $paralist := request:get-parameter-names()
return
      if(exists($paralist)) 
      then( 
               let $allparamvalues := 
                                     if ($parameter = $paralist) 
                                     then (request:get-parameter($parameter, ())) 
                                     else 'all'
                return
                       if ($allparamvalues = 'all') then () 
                       else ( 
                                if($parameter='xmlid') then (
                                            if($allparamvalues = '') then () 
                                            else if($allparamvalues != 'all') then "[contains(@xml:id, '" ||$allparamvalues||"')]" 
                                            else ())
                                else
                                      let $keys :=  if ($parameter = 'keyword')  then (
                                                                        for $k in $allparamvalues 
                                                                        let $ks := doc($config:data-rootA || '/taxonomy.xml')//t:catDesc[text() = $k]/following-sibling::t:*/t:catDesc/text() 
                                                                         let $nestedCats := for $n in $ks return $n 
                                                                           return 
                                                                            if ($nestedCats >= 2) then (replace($k, '#', ' ') || ' OR ' || string-join($nestedCats, ' OR ')) else (replace($k, '#', ' ')))
                                                             else(
                                                                         for $k in $allparamvalues 
                                                                          return 
                                                                          replace($k, '#', ' ') )
                                        return 
                                                if ($function = 'list')  then "[ft:query(" || $context || ", '" || string-join($keys, ' ') ||"')]"
                                                 else  
                                                         let $limit := for $k in $allparamvalues  
                                                                              return 
                                                                             if($parameter = 'author')
                                                                             then "descendant::" || $context || "='" || $k ||"' or  descendant::t:relation[@name='dcterms:creator']/@passive ='"|| $k ||"'"
                                                                           else if($parameter = 'tabot')
                                                                             then 
                                                                             "descendant::t:ab[@type='tabot'][descendant::t:persName[contains(@ref, '"||$k||"')] or descendant::t:ref[contains(@corresp, '"||$k||"')]]"
                                                                            
                                                                            else 
                                                                                         let $c := if(starts-with($context, '@')) then () else "descendant::"
                                                                                         return $c || $context || "='" || replace($k, ' ', '_') ||"' "
      
                                                          return "[" || string-join($limit, ' or ') || "]")
       ) else ()
};

    


(:~on login, print the name of the logged user:)
declare function app:greetings-rest(){
<a href="">Hi {xmldb:get-current-user()}!</a>
    };
(:on login, print the name of the logged user:)
declare function app:greetings($node as element(), $model as map(*)) as xs:string{
<a href="">Hi {xmldb:get-current-user()}!</a>
    };
    
 declare function app:logout(){
    session:invalidate()
    };

                        
                

(:~general count of contributions to the data:)
declare function app:team ($node as node(), $model as map(*)) {
<ul>{
    $config:collection-root/$app:range-lookup('changewho', (),
        function($key, $count) {
             <li class="lead">{editors:editorKey($key) || ' ('||$key||')' || ' made ' || $count[1] ||' changes in ' || $count[2]||' documents. '}<a href="/xpath?xpath=collection%28%27%2Fdb%2Fapps%2FBetMas%2Fdata%27%29%2F%2Ft%3Achange%5B%40who%3D%27{$key}%27%5D">See the changes.</a></li>
        }, 1000)
       }
       </ul>
};

declare function functx:value-intersect  ( $arg1 as xs:anyAtomicType* ,    $arg2 as xs:anyAtomicType* )  as xs:anyAtomicType* {

  distinct-values($arg1[.=$arg2])
 } ;

declare function functx:trim( $arg as xs:string? )  as xs:string {

   replace(replace($arg,'\s+$',''),'^\s+','')
 } ;

declare function functx:contains-any-of( $arg as xs:string? ,$searchStrings as xs:string* )  as xs:boolean {

   some $searchString in $searchStrings
   satisfies contains($arg,$searchString)
 } ;

(:modified by applying functx:escape-for-regex() :)
declare function functx:number-of-matches ( $arg as xs:string? ,$pattern as xs:string )  as xs:integer {
       
   count(tokenize(functx:escape-for-regex(functx:escape-for-regex($arg)),functx:escape-for-regex($pattern))) - 1
 } ;

declare function functx:escape-for-regex( $arg as xs:string? )  as xs:string {

   replace($arg,
           '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
 } ;


(:~ADVANCED SEARCH FUNCTIONS the list of searchable and indexed elements :)
declare function app:elements($node as node(), $model as map(*)) {
    let $control :=
        <select xmlns="http://www.w3.org/1999/xhtml" multiple="multiple" id="element" name="element" class="form-control">
            
            <option value="title">Titles</option>
            <option value="persName">Person names</option>
            <option value="placeName">Place names</option>
            <option value="ref">References</option>
            <option value="ab">Texts</option>
            <option value="l">Lines</option>
            <option value="p">Paragraphs</option>
            <option value="note">Notes</option>
            <option value="incipit">Incipits</option>
            <option value="explicit">Explicits</option>
            <option value="colophon">Colophons</option>
            <option value="q">Quotes</option>
            <option value="occupation">Occupation</option>
            <option value="roleName">Role</option>
            <option value="summary">Summaries</option>
            <option value="abstract">Abstracts</option>
            <option value="desc">Descriptions</option>
            <option value="relation">Relations</option>
            <option value="foliation">Foliation</option>
            <option value="origDate">Origin Dates</option>
            <option value="measure">Measures</option>
            <option value="floruit">Floruit</option>
        </select>
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS")
function app:target-mss($node as node(), $model as map(*), $context as xs:string*) {
  let $cont := util:eval($context)
      let $control :=
        app:formcontrol('target-ms', $cont//t:TEI, 'false', 'name', $context)
        
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootWN")
function app:target-works($node as node(), $model as map(*), $context as xs:string*) {
   let $cont := util:eval($context)
     let $control :=
    app:formcontrol('target-work', $cont//t:TEI, 'false', 'name', $context)
        
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootIn")
function app:target-ins($node as node(), $model as map(*), $context as xs:string*) {
   let $cont := util:eval($context)
    let $control :=
    app:formcontrol('target-ins', $cont//t:TEI, 'false', 'name', $context)
        
    return
        templates:form-control($control, $model)
};


(:~ called by form*.html files used by advances search form as.html and filters.js MANUSCRIPTS FILTERS for CONTEXT:)
declare 
%templates:default("context", "$config:collection-rootMS")
function app:scripts($node as node(), $model as map(*), $context as xs:string*) {
    let $cont := util:eval($context)
    let $scripts := $app:util-index-lookup($cont//@script, (), function($key, $count) {$key}, 100, 'lucene-index' )
    let $control := app:formcontrol('script', $scripts, 'false', 'values', $context)
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare 
%templates:default("context", "$config:collection-rootMS")
function app:support($node as node(), $model as map(*), $context as xs:string*) {
     let $cont := util:eval($context)
     let $forms := distinct-values($cont//@form)
     let $control := app:formcontrol('support', $forms, 'false', 'values', $context)
     return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS")
function app:material($node as node(), $model as map(*), $context as xs:string*) {
      let $cont := util:eval($context)
      let $materials := distinct-values($cont//t:support/t:material/@key)
      let $control := app:formcontrol('material', $materials, 'false', 'values', $context)
      return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS") 
function app:bmaterial($node as node(), $model as map(*), $context as xs:string*) {
    let $cont := util:eval($context)
      let $bmaterials := distinct-values($cont//t:decoNote[@type='bindingMaterial']/t:material/@key)
    
   let $control :=
        app:formcontrol('bmaterial', $bmaterials, 'false', 'values', $context)
    return
        templates:form-control($control, $model)
};


(:~ called by form*.html files used by advances search form as.html and filters.js PLACES FILTERS for CONTEXT:)
declare
%templates:default("context", "$config:collection-rootPlIn") 
function app:placeType($node as node(), $model as map(*), $context as xs:string*) {
      let $cont := util:eval($context)
     let $placeTypes := distinct-values($cont//t:place/@type/tokenize(., '\s+'))
    let $control := app:formcontrol('placeType', $placeTypes, 'false', 'values', $context)
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootPr") 
function app:personType($node as node(), $model as map(*), $context as xs:string*) {
    let $cont := util:eval($context)
      let $persTypes := distinct-values($cont//t:person//t:occupation/@type/tokenize(., '\s+'))
    let $control := app:formcontrol('persType', $persTypes, 'false', 'values', $context)
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-root") 
function app:relationType($node as node(), $model as map(*), $context as xs:string*) {
    let $cont := util:eval($context)
    let $relTypes := distinct-values($cont//t:relation/@name/tokenize(., '\s+'))
    let $control :=app:formcontrol('relType', $relTypes, 'false', 'values', $context)
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare function app:keywords($node as node(), $model as map(*), $context as xs:string*) {
    let $keywords := doc($config:data-rootA || '/taxonomy.xml')//t:taxonomy
   let $control := app:formcontrol('keyword', $keywords, 'false', 'keywords', $context)
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS") 
function app:languages($node as node(), $model as map(*), $context as xs:string*) {
     let $cont := util:eval($context)
     let $keywords := distinct-values($cont//t:language/@ident)
     let $control := app:formcontrol('language', $keywords, 'false', 'values', $context)
      return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS")  
function app:scribes($node as node(), $model as map(*), $context as xs:string*) {
     let $cont := util:eval($context)
      let $elements := $cont//t:persName[@role='scribe'][not(@ref= 'PRS00000')][ not(@ref= 'PRS0000')]
    let $keywords := distinct-values($elements/@ref)
    let $control := app:formcontrol('scribe', $keywords, 'false', 'rels', $context)
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS")   
function app:donors($node as node(), $model as map(*), $context as xs:string*) {
     let $cont := util:eval($context)
    let $elements := $cont//t:persName[@role='donor'][not(@ref= 'PRS00000')][ not(@ref= 'PRS0000')]
    let $keywords := distinct-values($elements/@ref)
   let $control :=app:formcontrol('donor', $keywords, 'false', 'rels', $context)
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS")   
function app:patrons($node as node(), $model as map(*), $context as xs:string*) {
     let $cont := util:eval($context)
      let $elements := $cont//t:persName[@role='patron'][not(@ref= 'PRS00000')][ not(@ref= 'PRS0000')]
    let $keywords := distinct-values($elements/@ref)
  let $control :=app:formcontrol('patron', $keywords, 'false', 'rels', $context)
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS")  
function app:owners($node as node(), $model as map(*), $context as xs:string*) {
      let $cont := util:eval($context)
      let $elements := $cont//t:persName[@role='owner'][not(@ref= 'PRS00000')][ not(@ref= 'PRS0000')]
      let $keywords := distinct-values($elements/@ref)
      let $control := app:formcontrol('owner', $keywords, 'false', 'rels', $context)
      return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS") 
function app:binders($node as node(), $model as map(*), $context as xs:string*) {
      let $cont := util:eval($context)
      let $elements := $cont//t:persName[@role='binder'][not(@ref= 'PRS00000')][ not(@ref= 'PRS0000')]
    let $keywords := distinct-values($elements/@ref)
   let $control := app:formcontrol('binder', $keywords, 'false', 'rels', $context)
    return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS")
function app:parmakers($node as node(), $model as map(*), $context as xs:string*) {
    let $cont := util:eval($context)
      let $elements := $cont//t:persName[@role='parchmentMaker'][not(@ref= 'PRS00000')][ not(@ref= 'PRS0000')]
    let $keywords := distinct-values($elements/@ref)
    let $control := app:formcontrol('parchmentMaker', $keywords, 'false', 'rels', $context)
       return
        templates:form-control($control, $model)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS")
function app:contents($node as node(), $model as map(*), $context as xs:string*) {
    let $cont := util:eval($context)
    let $elements :=$cont//t:msItem[not(contains(@xml:id, '.'))]
    let $titles := $elements/t:title/@ref
    let $keywords := distinct-values($titles)
  return
   app:formcontrol('content', $keywords, 'false', 'hierels', $context)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS")
function app:mss($node as node(), $model as map(*), $context as xs:string*) {
    let $cont := util:eval($context)
    let $keywords := for $r in $cont//t:witness/@corresp return string($r)|| ' '
   return
   app:formcontrol('ms', $keywords, 'false', 'hierels', $context)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare
%templates:default("context", "$config:collection-rootMS")
function app:WorkAuthors($node as node(), $model as map(*), $context as xs:string*) {
let $works := util:eval($context)
let $attributions := for $rel in ($works//t:relation[@name="saws:isAttributedToAuthor"], $works//t:relation[@name="dcterms:creator"])
let $r := $rel/@passive
                return 
                if (contains($r, ' ')) then tokenize($r, ' ') else $r  
let $keywords := distinct-values($attributions)
  return
   app:formcontrol('author', $keywords, 'false', 'rels', $context)
};

(:~ called by form*.html files used by advances search form as.html and filters.js :)
declare 
%templates:default("context", "$config:collection-rootIn") 
function app:tabots($node as node(), $model as map(*), $context as xs:string*) {
let $cont := util:eval($context)
let $tabots:= $cont//t:ab[@type='tabot']
    let $personTabot := distinct-values($tabots//t:persName/@ref) 
    let $thingsTabot := distinct-values($tabots//t:ref/@corresp)
    let $alltabots := ($personTabot, $thingsTabot)
  return
   app:formcontrol('tabot', $alltabots, 'false', 'rels', $context)
};


(:~ called by form*.html files used by advances search form as.html and filters.js IDS, TITLES, PERSNAMES, PLACENAMES, provide lists with guessing based on typing. the list must suggest a name but search for an ID:)
declare function app:BuildSearchQuery($element as xs:string, $query as xs:string){
let $SearchOptions :=
    <options>
        <default-operator>or</default-operator>
        <phrase-slop>0</phrase-slop>
        <leading-wildcard>yes</leading-wildcard>
        <filter-rewrite>yes</filter-rewrite>
    </options>
    return
concat("descendant::t:", $element, "[ft:query(., '" , $query, "', ", serialize($SearchOptions) ,")]")
};


(:~ a function simply evaluating an xpath entered as string:)
declare  function app:xpathQuery($node as node(), $model as map(*), $xpath as xs:string?) {
if(empty($xpath)) then 'Please enter a well formed Xpath expression' else 
let $logpath := log:add-log-message($xpath, xmldb:get-current-user(), 'XPath query')  
let $hits := for $hit in util:eval($xpath)
return $hit
 return            
map {"hits": $hits, "path": $xpath}
         
    };
    
    (:~ a function evaluating a sparql query, using the https://github.com/ljo/exist-sparql package:)
declare  function app:sparqlQuery($node as node(), $model as map(*), $query as xs:string?) {

if(empty($query)) then 'Please enter a valid SPARQL query.' else 
let $prefixes := $config:sparqlPrefixes
      
         
let $allquery := ($prefixes || normalize-space($query))
let $logpath := log:add-log-message($query, xmldb:get-current-user(), 'SPARQL query')  

let $results := sparql:query($allquery)
 return            
map {"sparqlResult": $results, "q": $query}
         
    };
    
    declare    
%templates:wrap
    function app:sparqlRes (
    $node as node(), 
    $model as map(*)) {
    transform:transform($model("sparqlResult")/sr:sparql, 'xmldb:exist:///db/apps/BetMas/rdfxslt/sparqltable.xsl', ())

    };
    
(:~ produces a piece of xpath for the query if the input is a range    :)
declare function app:paramrange($par, $path as xs:string){
    let $rangeparam := request:get-parameter($par, ())
   
     let $from := substring-before($rangeparam, ',') 
                let $to := substring-after($rangeparam, ',') 
                return
                if ($rangeparam = '0,2000')
                then ()
                else if ($rangeparam = '')
                then ()
                else
    ("[descendant::t:"||$path||"[. >=" || $from ||' ][ .  <= ' || $to || "]]")
    
    };


(:~
    Execute the query. The search results are not output immediately. Instead they
    are passed to nested templates through the $model parameter.
:)
declare 
    %templates:default("scope", "narrow")
    %templates:default("work-types", "all")
    %templates:default("target-ms", "all")
    %templates:default("target-work", "all")
    %templates:default("homophones", "true")
%templates:default("numberOfParts", "")
    %templates:default("element",  "placeName", "title", "persName", "ab", "floruit", "p", "note", "idno", "incipit", "explicit")
function app:query(
$node as node()*, 
$model as map(*), 
$query as xs:string*, 
$numberOfParts as xs:string*, 
    $work-types as xs:string+,
    $element as xs:string+,
    $target-ms as xs:string+,
    $target-work as xs:string+,
    $homophones as xs:string+   ) {
    let $homophones :=request:get-parameter('homophones', ())
   let $parameterslist := request:get-parameter-names()
   let $paramstobelogged := for $p in $parameterslist for $value in request:get-parameter($p, ()) return ($p || '=' || $value)
   let $logparams := '?' || string-join($paramstobelogged, '&amp;')
   let $log := log:add-log-message($logparams, xmldb:get-current-user(), 'query')
    let $IDpart := app:ListQueryParam('xmlid', '@xml:id', 'any', 'search')
    let $collection := app:ListQueryParam('work-types', '@type', 'any', 'search')
    let $script := app:ListQueryParam('script', 't:handNote/@script', 'any', 'search')
    let $mss := app:ListQueryParam('target-ms', '@xml:id', 'any', 'search')
    let $texts := app:ListQueryParam('target-work', '@xml:id', 'any', 'search')
    let $support := app:ListQueryParam('support', 't:objectDesc/@form', 'any', 'search')
    let $material := app:ListQueryParam('material', 't:support/t:material/@key', 'any', 'search')
    let $bmaterial := app:ListQueryParam('bmaterial', "t:decoNote[@type='bindingMaterial']/t:material/@key", 'any', 'search')
    let $placeType := app:ListQueryParam('placeType', 't:place/@type', 'any', 'search') 
    let $personType := app:ListQueryParam('persType', 't:person//t:occupation/@type', 'any', 'search')
    let $relationType := app:ListQueryParam('relType', 't:relation/@name', 'any', 'search')
    let $repository := app:ListQueryParam('target-ins', 't:repository/@ref ', 'any', 'search')
    let $keyword := app:ListQueryParam('keyword', 't:term/@key ', 'any', 'search')
    let $languages := app:ListQueryParam('language', 't:language/@ident', 'any', 'search')
let $scribes := app:ListQueryParam('scribe', "t:persName[@role='scribe']/@ref", 'any',  'search')
let $donors := app:ListQueryParam('donor', "t:persName[@role='donor']/@ref", 'any',  'search')
let $patrons := app:ListQueryParam('patron', "t:persName[@role='patron']/@ref", 'any', 'search')
let $owners := app:ListQueryParam('owner', "t:persName[@role='owner']/@ref", 'any',  'search')
let $parchmentMakers := app:ListQueryParam('parchmentMaker', "t:persName[@role='parchmentMaker']/@ref", 'any',  'search')
let $binders := app:ListQueryParam('binder', "t:persName[@role='binder']/@ref", 'any',  'search')
let $contents := app:ListQueryParam('content', "t:title/@ref", 'any', 'search')
let $wits := app:ListQueryParam('ms', "t:witness/@corresp", 'any', 'search')
let $authors := app:ListQueryParam('author', "t:relation[@name='saws:isAttributedToAuthor']/@passive", 'any', 'search')
(:let $authorsCertain := app:ListQueryParam('author', "t:relation[@name='dcterms:creator']/@passive", 'any', 'search'):)
let $tabots := app:ListQueryParam('tabot', "t:ab[@type='tabot']/t:*/(@ref|@corresp)", 'any', 'search')
let $references := if (contains($parameterslist, 'references')) then let $refs := for $ref in tokenize(request:get-parameter('references', ()), ',') return "[descendant::t:*/@*[not(name()='xml:id')] ='"  ||$ref || "' ]" return string-join($refs, '') else ()
let $genders := if (contains($parameterslist, 'gender')) then '[descendant::t:person/@sex ='  ||request:get-parameter('gender', ()) || ' ]' else ()
let $leaves :=  if (contains($parameterslist, 'folia')) 
                then (
                let $range := request:get-parameter('folia', ())
                let $min := substring-before($range, ',') 
                let $max := substring-after($range, ',') 
                return
                if ($range = '1,1000')
                then ()
                else if (empty($range))
                then ()
                else
                "[descendant::t:extent/t:measure[@unit='leaf'][not(@type)][. >="||$min|| ' ][ .  <= ' || $max ||"]]"
               ) else ()
let $wL :=  if (contains($parameterslist, 'wL')) 
                then (
                let $range := request:get-parameter('wL', ())
                let $min := substring-before($range, ',') 
                let $max := substring-after($range, ',') 
                return
                if ($range = '1,1000')
                then ()
                else if (empty($range))
                then ()
                else
                "[descendant::t:layout[@writtenLines >="||$min|| '][@writtenLines  <= ' || $max ||"]]"
               ) else ()
let $quires :=  if (contains($parameterslist, 'qn')) 
                then (
                let $range := request:get-parameter('qn', ())
                return
                 if ($range = '1,100')
                then ()
                else
                app:paramrange('qn', "extent/t:measure[@unit='quire'][not(@type)]")
               ) else ()
let $quiresComp :=  if (contains($parameterslist, 'qcn')) 
                then (
                let $range := request:get-parameter('qcn', ())
                return
                 if ($range = '1,40')
                then ()
                else
                app:paramrange('qcn', "collation//t:dim[@unit='leaf']")
               ) else ()
let $dateRange := 
                if (contains($parameterslist, 'dataRange')) 
                then (
                let $range := request:get-parameter('dateRange', ())
                let $from := substring-before($range, ',') 
                let $to := substring-after($range, ',') 
                return
                if ($range = '0,2000')
                then ()
                else if ($range = '')
                then ()
                else
                "[descendant::t:*[(if 
(contains(@notBefore, '-')) 
then (substring-before(@notBefore, '-')) 
else @notBefore)[. !=''][. >= " || $from || '][.  <= ' || $to || "] 

or 
(if (contains(@notAfter, '-')) 
then (substring-before(@notAfter, '-')) 
else @notAfter)[. !=''][. >= " || $from || '][.  <= ' || $to || '] 

]
]' ) else ()
   let $height :=   if (contains($parameterslist, 'height')) then (app:paramrange('height', 'height')) else ()
   let $width :=  if (contains($parameterslist, 'width')) then (app:paramrange('width', 'width')) else ()
   let $depth :=  if (contains($parameterslist, 'depth')) then (app:paramrange('depth', 'depth')) else ()
   let $marginTop :=  if (contains($parameterslist, 'tmargin')) then (app:paramrange('tmargin', "dimension[@type='margin']/t:dim[@type='top']")) else ()
   let $marginBot :=  if (contains($parameterslist, 'bmargin')) then (app:paramrange('tmargin', "dimension[@type='margin']/t:dim[@type='bottom']")) else ()
   let $marginR :=  if (contains($parameterslist, 'rmargin')) then (app:paramrange('tmargin', "dimension[@type='margin']/t:dim[@type='right']")) else ()
   let $marginL :=  if (contains($parameterslist, 'lmargin')) then (app:paramrange('tmargin', "dimension[@type='margin']/t:dim[@type='left']")) else ()
   let $marginIntercolumn :=  if (contains($parameterslist, 'intercolumn')) then (app:paramrange('intercolumn', "dimension[@type='margin']/t:dim[@type='intercolumn']")) else ()
                            
let $query-string := if ($query != '') 
                                        then (
                                                                       if($homophones='true') 
                                                                       then 
                                                                                if(contains($query, 'AND')) then 
                                                                                (let $parts:= for $qpart in tokenize($query, 'AND') 
                                                                                return all:substitutionsInQuery($qpart) return 
                                                                                '(' || string-join($parts, ') AND (')) || ')'
                                                                                else if(contains($query, 'OR')) then 
                                                                                (let $parts:= for $qpart in tokenize($query, 'OR') 
                                                                                return all:substitutionsInQuery($qpart) return 
                                                                                '(' || string-join($parts, ') OR (')) || ')'
                                                                                else all:substitutionsInQuery($query) 
                                                                       else $query)  
                                        else ()

let $eachworktype := for $wtype in request:get-parameter('work-types', ()) 
                                   return  "@type='"|| $wtype || "'" || (
(:                                   in case there is only one collection parameter selected and this is equal to place, search also institutions :)
                                   if(count(request:get-parameter('work-types', ())) eq 1 and request:get-parameter('work-types', ()) = 'place' ) then ("or @type='ins'")   else '')
        
let $wt := if(contains($parameterslist, 'work-types')) then "[" || string-join($eachworktype, ' or ') || "]" else ()
let $nOfP := if(empty($numberOfParts) or $numberOfParts = '') then () else '[count(descendant::t:msPart) ge ' || $numberOfParts || ']'


let $allfilters := concat($IDpart, $wt, $repository, $mss, $texts, $script, $support, 
             $material, $bmaterial, $placeType, $personType, $relationType, 
             $keyword, $languages, $scribes, $donors, $patrons, $owners, $parchmentMakers, 
             $binders, $contents, $authors, $tabots, $genders, $dateRange, $leaves, $wL,  $quires, $quiresComp,
             $references, $height, $width, $depth, $marginTop, $marginBot, $marginL, $marginR, $marginIntercolumn)
         
(:         the evalutaion of the entire string for the query makes it impossible to use range indexes in a proper way,
the same for the elements evaluated with the OR operator in one argument for the path.
this should update the query results for each parameter, updating the variable step by step
for the elements to be searched it should search one by one AFTER applying the filters, so only in the items filter out and then 
union the sequences of results and remove the doubles from the union
:)
         
         
let $queryExpr := $query-string
    return
        if (empty($queryExpr) or $queryExpr = "") then
          (if(empty($parameterslist)) then () else ( let $hits := 
             let $path := 
             concat("$config:collection-root","//t:TEI", 
             $allfilters, $nOfP)
             return
                   for $hit in util:eval($path)
                   return $hit
                 
            
            return
                map {
                    "hits" := $hits,
                    "type" := 'records'
                    
                } ))
        else
          
          let $hits :=

                 let $elements : =
                   for $e in $element
                   return 
                   app:BuildSearchQuery($e, $query-string)
                   
                   let $allels := string-join($elements, ' or ')
                   let $path:=    concat("$config:collection-root","//t:TEI[",$allels, "]", $allfilters)
                   let $logpath := log:add-log-message($path, xmldb:get-current-user(), 'XPath')  
                   for $hit in util:eval($path)
                    order by ft:score($hit) descending
                    return $hit
                    
              
            
            let $store := (
                session:set-attribute("apps.BetMas", $hits),
                session:set-attribute("apps.BetMas.query", $queryExpr)
            )
            return
                (: Process nested templates :)
                map {
                    "hits" := $hits,
                    "q" := $query,
                    "type" := 'matches',
                    "query" := $queryExpr
                }
};



(:~
    Helper function: create a lucene query from the user input
:)
declare function app:create-query($query-string as xs:string?, $mode as xs:string) {
    let $query-string := 
        if ($query-string) 
        then app:sanitize-lucene-query($query-string) 
        else ''
    let $query-string := normalize-space($query-string)
   let $query-string := if(contains($query-string, 's')) then let $options := replace($query-string, 's', 'ḍ')  return ($query-string || ' ' || $options)  else $query-string
    let $query-string := if(contains($query-string, 'e')) then let $options := (replace($query-string, 'e', 'ǝ'),replace($query-string, 'e', 'ē'))  return ($query-string || ' ' || string-join($options, ' '))  else $query-string
   
    (:Remove/ignore ayn and alef :)
    let $query-string := if(contains($query-string, 'ʾ')) then let $options := replace($query-string, "ʾ", "")  return ($query-string || ' ' || string-join($options, ' '))  else $query-string
   let $query-string := if(contains($query-string, 'ʿ')) then let $options := replace($query-string, "ʿ", "")  return ($query-string || ' ' || string-join($options, ' '))  else $query-string
    
   let $query:=
        (:If the query contains any operator used in sandard lucene searches or regex searches, pass it on to the query parser;:) 
        if (functx:contains-any-of($query-string, ('AND', 'OR', 'NOT', '+', '-', '!', '~', '^', '.', '?', '*', '|', '{','[', '(', '<', '@', '#', '&amp;')) and $mode eq 'any')
        then 
            let $luceneParse := app:parse-lucene($query-string)
            let $luceneXML := util:parse($query-string)
            let $lucene2xml := app:lucene2xml($luceneXML/node(), $mode)
            return $lucene2xml
        (:otherwise the query is performed by selecting one of the special options (any, all, phrase, near, fuzzy, wildcard or regex):)
        else
            let $query-string := tokenize($query-string, '\s')
            let $last-item := $query-string[last()]
            let $query-string := 
                if ($last-item castable as xs:integer) 
                then string-join(subsequence($query-string, 1, count($query-string) - 1), ' ') 
                else string-join($query-string, ' ')
                
                
            let $query :=
                <query>
                    {
                        if ($mode eq 'any') 
                        then
                            for $term in tokenize($query-string, '\s')
                            return <term occur="should">{$term}</term>
                        else if ($mode eq 'all') 
                        then
                            <bool>
                            {
                                for $term in tokenize($query-string, '\s')
                                return <term occur="must">{$term}</term>
                            }
                            </bool>
                        else 
                            if ($mode eq 'phrase') 
                            then <phrase>{$query-string}</phrase>
                       else
                                if ($mode eq 'near-unordered')
                                then <near slop="{if ($last-item castable as xs:integer) then $last-item else 5}" ordered="no">{$query-string}</near>
                        else 
                                    if ($mode eq 'near-ordered')
                                    then <near slop="{if ($last-item castable as xs:integer) then $last-item else 5}" ordered="yes">{$query-string}</near>
                                    else 
                                        if ($mode eq 'fuzzy')
                                        then <fuzzy max-edits="{if ($last-item castable as xs:integer and number($last-item) < 3) then $last-item else 2}">{$query-string}</fuzzy>
                                        else 
                                            if ($mode eq 'wildcard')
                                            then <wildcard>{$query-string}</wildcard>
                                            else 
                                                if ($mode eq 'regex')
                                                then <regex>{$query-string}</regex>
                                                else ()
                    }</query>
            return $query
    return $query
    
};


(: SIMPLE search :)



(:~
 : FROM SHAKESPEAR
    Create a span with the number of items in the current search result.
:)
declare function app:hit-count($node as node()*, $model as map(*)) {
    if ($model('type') = 'bibliography') then <h3>There are <span xmlns="http://www.w3.org/1999/xhtml" id="hit-count">{ count($model("hits")) }</span> distinct bibliographical references</h3> else if ($model('type') = 'matches') then <h3>You found "{$app:searchphrase}" in <span xmlns="http://www.w3.org/1999/xhtml" id="hit-count">{ count($model("hits")) }</span> results</h3> else (<h3> There are <span xmlns="http://www.w3.org/1999/xhtml" id="hit-count">{ count($model("hits")) }</span> entities matching your query. </h3>)
    
};

declare function app:hit-params($node as node()*, $model as map(*)) {
    <div>{
                    for $param in request:get-parameter-names()
                    for $value in request:get-parameter($param, ())
                    return
                    if ($param = 'start') then ()
                    else if ($param = 'query') then ()
                    else if ($param = 'dateRange') 
                     then (<button type="button" class="btn btn-sm btn-info">{'between ' || substring-before(request:get-parameter('dateRange', ()), ',') || ' and ' || substring-after(request:get-parameter('dateRange', ()), ',')}</button>)
                    else
                        <button type="button" class="btn btn-sm btn-info">{($param || ": ", <span class="badge">{$value}</span>)}</button>
                }</div>
};

declare function app:gotoadvanced($node as node()*, $model as map(*)){
let $query := request:get-parameter('query', ())
return 
<a href="/as.html?query={$query}" class="btn btn-primary">Repeat search in the Advanced Search.</a>
};

declare function app:list-count($node as node()*, $model as map(*)) {
    <h3>{$app:collection || ' '}{string-join(
                    for $param in request:get-parameter-names()
                    for $value in request:get-parameter($param, ())
                    return
                    if ($param = 'start') then ()
                    else if ($param = 'collection') then ()
                    else if ($param = 'dateRange') then ('between ' || substring-before(request:get-parameter('dateRange', ()), ',') || ' and ' || substring-after(request:get-parameter('dateRange', ()), ','))
                    else
                        $param || ": " || $value, ", " 
                )}: <span xmlns="http://www.w3.org/1999/xhtml" id="hit-count">{ count($model("hits")) }</span></h3>
};


(:~
 : FROM SHAKESPEAR
 : Create a bootstrap pagination element to navigate through the hits.
 :)
 
 declare
    %templates:wrap
    %templates:default('start', 1)
    %templates:default("per-page", 20)
    %templates:default("min-hits", 0)
    %templates:default("max-pages", 20)
function app:paginate($node as node(), $model as map(*), $start as xs:int, $per-page as xs:int, $min-hits as xs:int,
    $max-pages as xs:int) {
        
    if ($min-hits < 0 or count($model("hits")) >= $min-hits) then
        let $types := if($model("type") = 'bibliography' or $model("type") = 'indexes')
        then(count($model("hits"))) 
        else
        for $x in $model("hits") 
                                  group by $t := root($x)/t:TEI/@type 
                                return 
                                count($x)
        let $count := xs:integer(ceiling(max($types)) div $per-page) + 1
        let $middle := ($max-pages + 1) idiv 2
        let $params :=
                string-join(
                    for $param in request:get-parameter-names()
                    for $value in request:get-parameter($param, ())
                    return
                    if ($param = 'start') then ()
                    else if ($param = 'collection') then ()
                    else
                        $param || "=" || $value,
                    "&amp;"
                )
        return (
            if ($start = 1) then (
                <li class="disabled">
                    <a><i class="glyphicon glyphicon-fast-backward"/></a>
                </li>,
                <li class="disabled">
                    <a><i class="glyphicon glyphicon-backward"/></a>
                </li>
            ) else (
                <li>
                    <a href="?{$params}&amp;start=1"><i class="glyphicon glyphicon-fast-backward"/></a>
                </li>,
                <li>
                    <a href="?{$params}&amp;start={max( ($start - $per-page, 1 ) ) }"><i class="glyphicon glyphicon-backward"/></a>
                </li>
            ),
            let $startPage := xs:integer(ceiling($start div $per-page))
            let $lowerBound := max(($startPage - ($max-pages idiv 2), 1))
            let $upperBound := min(($lowerBound + $max-pages - 1, $count))
            let $lowerBound := max(($upperBound - $max-pages + 1, 1))
            for $i in $lowerBound to $upperBound
            return
                if ($i = ceiling($start div $per-page)) then
                    <li class="active"><a href="?{$params}&amp;start={max( (($i - 1) * $per-page + 1, 1) )}">{$i}</a></li>
                else
                    <li><a href="?{$params}&amp;start={max( (($i - 1) * $per-page + 1, 1)) }">{$i}</a></li>,
            if ($start + $per-page < count($model("hits"))) then (
                <li>
                    <a href="?{$params}&amp;start={$start + $per-page}"><i class="glyphicon glyphicon-forward"/></a>
                </li>,
                <li>
                    <a href="?{$params}&amp;start={max( (($count - 1) * $per-page + 1, 1))}"><i class="glyphicon glyphicon-fast-forward"/></a>
                </li>
            ) else (
                <li class="disabled">
                    <a><i class="glyphicon glyphicon-forward"/></a>
                </li>,
                <li>
                    <a><i class="glyphicon glyphicon-fast-forward"/></a>
                </li>
            )
        ) else
            ()
};



declare    
%templates:wrap
    %templates:default('start', 1)
    %templates:default("per-page", 10)
    function app:searchRes (
    $node as node()*, 
    $model as map(*), $start as xs:integer,  $per-page as xs:integer) {
        switch($model("type"))
        case 'matches' return
    for $text at $p in $model('hits')
        let $root := root($text)
        let $t := $root/t:TEI/@type
        group by $type := $t
        let $collection := switch:col($type)
        
        return
        <div class="col-md-12 results{$collection}">
        <h4>{count($text)} result{if(count($text) gt 1) then 's' else ''} in {$collection}</h4>
        {
        for $tex at $p in subsequence($text, $start, $per-page)
        let $expanded := kwic:expand($tex)
          let $root := root($tex)
         let $count := count($expanded//exist:match)
        let $id := data($root/t:TEI/@xml:id)
        
        let $score as xs:float := ft:score($tex)
         return
            <div class="row reference">
            <div class="col-md-4">
            <div class="col-md-2">
                <span class="number">{$start + $p - 1}</span>
                </div>
             <div class="col-md-8"><a target="_blank" href="/{$collection}/{$id}/main" class="MainTitle" data-value="{$id}">{$id}</a> ({$id})</div>
                       <div class="col-md-2">
                <span class="badge">{$count}</span>
                </div>
            </div>
            
            <div class="col-md-8">
            
                 <div class="col-md-8">{for $match in subsequence($expanded//exist:match, 1, 3) return  kwic:get-summary($expanded, $match,<config width="40"/>)}</div>
                        
                        <div class="col-md-4">{data($text/ancestor::t:*[@xml:id][1]/@xml:id)}</div>
                        </div>
                    </div>
       }</div>
                default return 
                
                 for $text in $model('hits')
        let $root := root($text)
        let $t := $root/t:TEI/@type
        group by $type := $t
        let $collection := switch:col($type)
        
        return
        <div class="col-md-12 results{$collection}">
        <h4>{count($text)} result{if(count($text) gt 1) then 's' else ''} in {$collection}</h4>
        {
        for $tex at $p in subsequence($text, $start, $per-page)
        let $root := root($tex)
        let $id := data($root/t:TEI/@xml:id)
        let $collection := switch:col($root/t:TEI/@type)
         return
            <div class="row reference">
                <div class="col-md-2"><span class="number">{$start + $p - 1}</span></div>
                        <div class="col-md-5"><a target="_blank" href="/{$collection}/{$id}/main">{titles:printTitleID($id)}</a> ({$id})</div>
                        <div class="col-md-5">{data($root/t:TEI/@type)}</div>
                       
                    </div>
       }</div>
                

    };
    
    
    declare %templates:wrap function app:xpathresultstitle($node as node(), 
    $model as map(*)){
    <h2>{count($model("hits"))} results for { $model("path")} </h2>
    };
    
  
    
    declare %templates:wrap function app:sparqlresultstitle($node as node(), 
    $model as map(*)){
    <p>Your query: <span style="color:grey;font-style:italic">{$model("q")}</span> returned <span class="label label-info">{count($model("sparqlResult")//sr:result)}</span> results</p>
    };
    
    declare    
%templates:wrap
    %templates:default('start', 1)
    %templates:default("per-page", 10) 
    function app:XpathRes (
    $node as node(), 
    $model as map(*), $start as xs:integer, $per-page as xs:integer) {
        
    for $text at $p in subsequence($model("hits"), $start, $per-page)
        let $root := root($text)
        let $id := data($root/t:TEI/@xml:id)
         return
            <div class="row reference">
                <div class="col-md-1"><span class="number">{$start + $p - 1}</span></div>
                        <div class="col-md-3"><a href="/{$id}">{titles:printTitleID($id)}</a> ({$id})</div>
                        <div class="col-md-5"></div>
                        
                        <div class="col-md-1">{data($text/ancestor::t:*[@xml:id][1]/@xml:id)}</div>
                        <div class="col-md-2"> <code>{$text/name()}</code></div>
                    </div>
       
                
        

    };
    
    
(: copy all parameters, needed for search :)

declare function app:copy-params($node as node(), $model as map(*)) {
    element { node-name($node) } {
        $node/@* except $node/@href,
        attribute href {
            let $link := $node/@href
            let $params :=
                string-join(
                    for $param in request:get-parameter-names()
                    for $value in request:get-parameter($param, ())
                    return
                        $param || "=" || $value,
                    "&amp;"
                )
            return
                $link || "?" || $params
        },
        $node/node()
    }
};



(: This functions provides crude way to avoid the most common errors with paired expressions and apostrophes. :)
(: TODO: check order of pairs:)
declare %private function app:sanitize-lucene-query($query-string as xs:string) as xs:string {
    let $query-string := replace($query-string, "'", "''") (:escape apostrophes:)
    (:TODO: notify user if query has been modified.:)
    
    (:Remove colons – Lucene fields are not supported.:)
    let $query-string := translate($query-string, ":", " ")
    let $query-string := 
	   if (functx:number-of-matches($query-string, '"') mod 2) 
	   then $query-string
	   else replace($query-string, '"', ' ') (:if there is an uneven number of quotation marks, delete all quotation marks.:)
    let $query-string := 
	   if ((functx:number-of-matches($query-string, '\(') + functx:number-of-matches($query-string, '\)')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '()', ' ') (:if there is an uneven number of parentheses, delete all parentheses.:)
    let $query-string := 
	   if ((functx:number-of-matches($query-string, '\[') + functx:number-of-matches($query-string, '\]')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '[]', ' ') (:if there is an uneven number of brackets, delete all brackets.:)
    let $query-string := 
	   if ((functx:number-of-matches($query-string, '{') + functx:number-of-matches($query-string, '}')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '{}', ' ') (:if there is an uneven number of braces, delete all braces.:)
    let $query-string := 
	   if ((functx:number-of-matches($query-string, '<') + functx:number-of-matches($query-string, '>')) mod 2 eq 0) 
	   then $query-string
	   else translate($query-string, '<>', ' ') (:if there is an uneven number of angle brackets, delete all angle brackets.:)
    return $query-string
};

(: Function to translate a Lucene search string to an intermediate string mimicking the XML syntax, 
with some additions for later parsing of boolean operators. The resulting intermediary XML search string will be parsed as XML with util:parse(). 
Based on Ron Van den Branden, https://rvdb.wordpress.com/2010/08/04/exist-lucene-to-xml-syntax/:)
(:TODO:
The following cases are not covered:
1)
<query><near slop="10"><first end="4">snake</first><term>fillet</term></near></query>
as opposed to
<query><near slop="10"><first end="4">fillet</first><term>snake</term></near></query>

w(..)+d, w[uiaeo]+d is not treated correctly as regex.
:)
declare %private function app:parse-lucene($string as xs:string) {
    (: replace all symbolic booleans with lexical counterparts :)
    if (matches($string, '[^\\](\|{2}|&amp;{2}|!) ')) 
    then
        let $rep := 
            replace(
            replace(
            replace(
                $string, 
            '&amp;{2} ', 'AND '), 
            '\|{2} ', 'OR '), 
            '! ', 'NOT ')
        return app:parse-lucene($rep)                
    else 
        (: replace all booleans with '<AND/>|<OR/>|<NOT/>' :)
        if (matches($string, '[^<](AND|OR|NOT) ')) 
        then
            let $rep := replace($string, '(AND|OR|NOT) ', '<$1/>')
            return app:parse-lucene($rep)
        else 
            (: replace all '+' modifiers in token-initial position with '<AND/>' :)
            if (matches($string, '(^|[^\w&quot;])\+[\w&quot;(]'))
            then
                let $rep := replace($string, '(^|[^\w&quot;])\+([\w&quot;(])', '$1<AND type=_+_/>$2')
                return app:parse-lucene($rep)
            else 
                (: replace all '-' modifiers in token-initial position with '<NOT/>' :)
                if (matches($string, '(^|[^\w&quot;])-[\w&quot;(]'))
                then
                    let $rep := replace($string, '(^|[^\w&quot;])-([\w&quot;(])', '$1<NOT type=_-_/>$2')
                    return app:parse-lucene($rep)
                else 
                    (: replace parentheses with '<bool></bool>' :)
                    (:NB: regex also uses parentheses!:) 
                    if (matches($string, '(^|[\W-[\\]]|>)\(.*?[^\\]\)(\^(\d+))?(<|\W|$)'))                
                    then
                        let $rep := 
                            (: add @boost attribute when string ends in ^\d :)
                            (:if (matches($string, '(^|\W|>)\(.*?\)(\^(\d+))(<|\W|$)')) 
                            then replace($string, '(^|\W|>)\((.*?)\)(\^(\d+))(<|\W|$)', '$1<bool boost=_$4_>$2</bool>$5')
                            else:) replace($string, '(^|\W|>)\((.*?)\)(<|\W|$)', '$1<bool>$2</bool>$3')
                        return app:parse-lucene($rep)
                    else 
                        (: replace quoted phrases with '<near slop="0"></bool>' :)
                        if (matches($string, '(^|\W|>)(&quot;).*?\2([~^]\d+)?(<|\W|$)')) 
                        then
                            let $rep := 
                                (: add @boost attribute when phrase ends in ^\d :)
                                (:if (matches($string, '(^|\W|>)(&quot;).*?\2([\^]\d+)?(<|\W|$)')) 
                                then replace($string, '(^|\W|>)(&quot;)(.*?)\2([~^](\d+))?(<|\W|$)', '$1<near boost=_$5_>$3</near>$6')
                                (\: add @slop attribute in other cases :\)
                                else:) replace($string, '(^|\W|>)(&quot;)(.*?)\2([~^](\d+))?(<|\W|$)', '$1<near slop=_$5_>$3</near>$6')
                            return app:parse-lucene($rep)
                        else (: wrap fuzzy search strings in '<fuzzy max-edits=""></fuzzy>' :)
                            if (matches($string, '[\w-[<>]]+?~[\d.]*')) 
                            then
                                let $rep := replace($string, '([\w-[<>]]+?)~([\d.]*)', '<fuzzy max-edits=_$2_>$1</fuzzy>')
                                return app:parse-lucene($rep)
                            else (: wrap resulting string in '<query></query>' :)
                                concat('<query>', replace(normalize-space($string), '_', '"'), '</query>')
};

(: Function to transform the intermediary structures in the search query generated through app:parse-lucene() and util:parse() 
to full-fledged boolean expressions employing XML query syntax. 
Based on Ron Van den Branden, https://rvdb.wordpress.com/2010/08/04/exist-lucene-to-xml-syntax/:)
declare %private function app:lucene2xml($node as item(), $mode as xs:string) {
    typeswitch ($node)
        case element(query) return 
            element { node-name($node)} {
            element bool {
            $node/node()/app:lucene2xml(., $mode)
        }
    }
    case element(AND) return ()
    case element(OR) return ()
    case element(NOT) return ()
    case element() return
        let $name := 
            if (($node/self::phrase | $node/self::near)[not(@slop > 0)]) 
            then 'phrase' 
            else node-name($node)
        return
            element { $name } {
                $node/@*,
                    if (($node/following-sibling::*[1] | $node/preceding-sibling::*[1])[self::AND or self::OR or self::NOT or self::bool])
                    then
                        attribute occur {
                            if ($node/preceding-sibling::*[1][self::AND]) 
                            then 'must'
                            else 
                                if ($node/preceding-sibling::*[1][self::NOT]) 
                                then 'not'
                                else 
                                    if ($node[self::bool]and $node/following-sibling::*[1][self::AND])
                                    then 'must'
                                    else
                                        if ($node/following-sibling::*[1][self::AND or self::OR or self::NOT][not(@type)]) 
                                        then 'should' (:must?:) 
                                        else 'should'
                        }
                    else ()
                    ,
                    $node/node()/app:lucene2xml(., $mode)
        }
    case text() return
        if ($node/parent::*[self::query or self::bool]) 
        then
            for $tok at $p in tokenize($node, '\s+')[normalize-space()]
            (:Here the query switches into regex mode based on whether or not characters used in regex expressions are present in $tok.:)
            (:It is not possible reliably to distinguish reliably between a wildcard search and a regex search, so switching into wildcard searches is ruled out here.:)
            (:One could also simply dispense with 'term' and use 'regex' instead - is there a speed penalty?:)
                let $el-name := 
                    if (matches($tok, '((^|[^\\])[.?*+()\[\]\\^|{}#@&amp;<>~]|\$$)') or $mode eq 'regex')
                    then 'regex'
                    else 'term'
                return 
                    element { $el-name } {
                        attribute occur {
                        (:if the term follows AND:)
                        if ($p = 1 and $node/preceding-sibling::*[1][self::AND]) 
                        then 'must'
                        else 
                            (:if the term follows NOT:)
                            if ($p = 1 and $node/preceding-sibling::*[1][self::NOT])
                            then 'not'
                            else (:if the term is preceded by AND:)
                                if ($p = 1 and $node/following-sibling::*[1][self::AND][not(@type)])
                                then 'must'
                                    (:if the term follows OR and is preceded by OR or NOT, or if it is standing on its own:)
                                else 'should'
                    }
                    (:,
                    if (matches($tok, '((^|[^\\])[.?*+()\[\]\\^|{}#@&amp;<>~]|\$$)')) 
                    then
                        (\:regex searches have to be lower-cased:\)
                        attribute boost {
                            lower-case(replace($tok, '(.*?)(\^(\d+))(\W|$)', '$3'))
                        }
                    else ():)
        ,
        (:regex searches have to be lower-cased:)
        lower-case(normalize-space(replace($tok, '(.*?)(\^(\d+))(\W|$)', '$1')))
        }
        else normalize-space($node)
    default return
        $node
};


(:function defined by Wicentowski Joe joewiz@gmail.com on exist open mailing list for the Last created document in the collection:)
declare function app:get-latest-created-document($collection-uri as xs:string) as map(*) {
    if (xmldb:collection-available($collection-uri)) then
        let $documents := xmldb:xcollection($collection-uri) ! util:document-name(.)
        return
            if (exists($documents)) then
                let $latest-created :=
                    $documents
                    => sort((), xmldb:created($collection-uri, ?))
                    => subsequence(last())
                return
                    map {
                        "collection-uri": $collection-uri,
                        "document-name": $latest-created,
                        "created": xmldb:created($collection-uri, $latest-created)
                    }
            else
                map {
                    "warning": "No child documents in collection " || $collection-uri
                }
    else 
        map {
            "warning": "No such collection " || $collection-uri
        }
  };
  



declare  function app:worksforclavis($node as node(), $model as map(*), $xpath as xs:string?) {
  let $hits := for $hit in $config:collection-rootW//t:TEI[not(ends-with(@xml:id, 'IHA'))]
                    return $hit
   return
  map {"hits": $hits, "path": $xpath}

      };


  declare
  %templates:wrap
  %templates:default('start', 1)
  %templates:default("per-page", 20)
  function app:worksclavis(
      $node as node()*,
      $model as map(*),
      $start as xs:integer,
      $per-page as xs:integer) {

  for $text at $p in subsequence($model("hits"), $start, $per-page)
          let $root := root($text)
          let $id := data($root/t:TEI/@xml:id)
          let $maintitle := titles:printTitleMainID($id)
          let $clavis := app:clavisIds($root)
           return
              <div class="row reference" style="margin-bottom:20px;border-bottom: double;">
                  <div class="col-md-6">
                  <div class="col-md-6">
                  <span class="label label-info work">{$id}</span><h3>{$maintitle}</h3>{$clavis}
                      
                  </div>
                  <div class="col-md-6">{
                  for $title at $t in $text//t:titleStmt/t:title
                  let $dv := $id||'TITLE'||$t
                  return
                  <div class="row">
                  <div class="col-md-9"><p data-value="{$dv}">{$title/text()}</p></div>
                  <div class="col-md-3"><button data-value="{$dv}"
                  class="btn btn-default searchthis">search this</button></div>
                  </div>
                  }</div>
                  </div>
                  <div class="col-md-6"><label>Search PATHs/CMCL project data for matching clavis ids for {$id}</label><input id="{$id}" class="form-control querystring" type="text"/><div class="pathsResults"/></div>


              </div>
  };

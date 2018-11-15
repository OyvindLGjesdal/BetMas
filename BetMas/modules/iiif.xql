xquery version "3.1" encoding "UTF-8";
(:~
 : implementation of the http://iiif.io/api/presentation/2.1/ 
 : for images of manuscripts stored in betamasaheft server. extracts manifest, sequence, canvas from the tei data
 : 
 : @author Pietro Liuzzo <pietro.liuzzo@uni-hamburg.de'>
 :)
module namespace iiif = "https://www.betamasaheft.uni-hamburg.de/BetMas/iiif";
import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace log="http://www.betamasaheft.eu/log" at "log.xqm";
import module namespace all="https://www.betamasaheft.uni-hamburg.de/BetMas/all" at "all.xqm";
import module namespace titles="https://www.betamasaheft.uni-hamburg.de/BetMas/titles" at "titles.xqm";
import module namespace api="https://www.betamasaheft.uni-hamburg.de/BetMas/api" at "rest.xql";
import module namespace config = "https://www.betamasaheft.uni-hamburg.de/BetMas/config" at "config.xqm";
import module namespace kwic = "http://exist-db.org/xquery/kwic"
    at "resource:org/exist/xquery/lib/kwic.xql";
    
(: namespaces of data used :)
declare namespace t = "http://www.tei-c.org/ns/1.0";
declare namespace dcterms = "http://purl.org/dc/terms";
declare namespace saws = "http://purl.org/saws/ontology";
declare namespace cmd = "http://www.clarin.eu/cmd/";
declare namespace skos = "http://www.w3.org/2004/02/skos/core#";
declare namespace rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace s = "http://www.w3.org/2005/xpath-functions";
declare namespace sparql = "http://www.w3.org/2005/sparql-results#";

(: For REST annotations :)
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";


(:
produces jsonLD for the ES manuscripts whose images are exposed by our iipimage server
http://iiif.io/api/presentation/2.0/

:)

declare variable $iiif:response200 := $config:response200Json;

declare variable $iiif:response400 := $config:response400;

(:functions doing microtasks for the structures :)

declare function iiif:manifestsource($item as node()){
(:ES:)
            if($item//t:collection = 'Ethio-SPaRe') 
            then $config:appUrl ||'/api/iiif/' || string($item/@xml:id) || '/manifest' 
            else if($item//t:collection = 'EMIP') 
            then $config:appUrl ||'/api/iiif/' || string($item/@xml:id) || '/manifest' 
            (:BNF:)
            else if ($item//t:repository[@ref = 'INS0303BNF']) 
            then replace($item//t:msIdentifier/t:idno/@facs, 'ark:', 'iiif/ark:') || '/manifest.json'
(:           vatican :)
            else 
                if(starts-with($item//t:msIdentifier/t:idno/@facs, 'http://digi.vatlib')) 
            then replace($item//t:msIdentifier/t:idno/@facs, 'http://', 'https://') 
            else $item//t:msIdentifier/t:idno/@facs

};

declare function iiif:folio($folio as xs:string){if(matches($folio, '\d')) then xs:integer(replace(replace($folio, '[rvab]', ''), '#', '')) else 0};

declare function iiif:locus($l as node()){
  if($l[@from][@to]) 
                            then (let $f := iiif:folio($l/@from)
                                     let $t := iiif:folio($l/@to)
                                     for $x in $f to $t return $x) 
                     else if($l[@target]) 
                             then (if(contains($l/@target, ' '))
                                                                  then (for $t in tokenize($l/@target, ' ') return iiif:folio($t))
                                                                  else iiif:folio($l/@target)
                                       )
                    else if($l[@from][not(@to)]) 
                            then ( iiif:folio($l/@from)) 
                    else ()};

declare function iiif:range($iiifroot as xs:string, $structure as xs:string, $title as xs:string, $locusrange){
      let $canvases := for $folio in $locusrange return $iiifroot || '/canvas/p'  || $folio
      let $cs := if(count($canvases) eq 1) then 
      let $lastDigit:= let $thislast := substring-after($canvases, '/canvas/p')
                             let $newnum := number($thislast) +1
                               return replace($canvases, '/p\d+$', ('/p' || xs:string($newnum)))
      return ($canvases, $lastDigit) else $canvases
       return
       map {"@context":= "http://iiif.io/api/presentation/2/context.json",
      "@id": $structure,
      "@type": "sc:Range",
      "label": $title,
      "canvases": $cs}
};

declare function iiif:rangetype($iiifroot as xs:string, $name as xs:string, $title as xs:string, $seqran as xs:anyAtomicType+){
map {
      "@id":$iiifroot ||"/range/"|| $name,
      "@type":"sc:Range",
      "label": $title,
      "ranges" : if(count($seqran) = 1) then [$seqran] else $seqran
    }
};

declare function iiif:ranges($iiifroot as xs:string, $ranges as node()){
for $r in $ranges/range
       let $locusrange :=  for $l in $r/t:*/t:locus return iiif:locus($l)
      return iiif:range($iiifroot, $r/r, $r/t, $locusrange)
};


declare function iiif:rangeAndsubrange($iiifroot as xs:string, $ranges as node(), $name as xs:string, $title as xs:string){

let $seqran :=  for $r in $ranges/range return $r/r
       return
  (iiif:rangetype($iiifroot, $name, $title, $seqran),
       iiif:ranges($iiifroot, $ranges)
   )
};


(:parts used by different requests:)

declare function iiif:annotation($id, $image, $resid){
map {"@context":"http://iiif.io/api/presentation/2/context.json",
      "@id": substring-before($id, '/canvas') || "/annotation/p0001-image",
  
      "@type": "oa:Annotation",
      "motivation": "sc:painting",
      "resource": map {
                    "@id": $image,
                    "@type": "dctypes:Image",
                    "format": "image/jpeg",
                    "service": map {
                        "@context": "http://iiif.io/api/image/2/context.json",
                        "@id": $resid,
                        "profile": "http://iiif.io/api/image/2/level1.json"
                    },
                    "height":1500,
                    "width":2000
                },
                "on": $id
              
    }
};

declare function iiif:oneCanvas($id, $name, $image, $resid){

map {"@context":= "http://iiif.io/api/presentation/2/context.json",
                   "@id": $id,
                   "@type": "sc:Canvas",
                   "label": $name,
                   "height":7500,
  "width":10000, 
  "images": [
    map {"@context":"http://iiif.io/api/presentation/2/context.json",
      "@id": substring-before($id, '/canvas') || "/annotation/p0001-image",
  
      "@type": "oa:Annotation",
      "motivation": "sc:painting",
      "resource": map {
                    "@id": $image,
                    "@type": "dctypes:Image",
                    "format": "image/jpeg",
                    "service": map {
                        "@context": "http://iiif.io/api/image/2/context.json",
                        "@id": $resid,
                        "profile": "http://iiif.io/api/image/2/level1.json"
                    },
                    "height":1500,
                    "width":2000
                },
                "on": $id
              
    }
  ]
                               }

};


declare function iiif:Canvases($item, $id, $iiifroot){
let $tot := $item//t:msIdentifier/t:idno/@n
let $imagesbaseurl := $config:appUrl ||'/iiif/' || string($item//t:msIdentifier/t:idno/@facs)
       
       return
 for $graphic at $p in 1 to $tot 
            let $n := $p
             let $imagefile := format-number($graphic, '000') || '.tif'
             let $resid := ($imagesbaseurl || (if($item//t:collection='EMIP') then () else '_') || $imagefile )
             let $image := ($imagesbaseurl || (if($item//t:collection='EMIP') then () else '_') || $imagefile || '/full/full/0/default.jpg' )
            let $name := string($n)
            let $id := $iiifroot || '/canvas/p'  || $n
              order by $p 
              return iiif:oneCanvas($id, $name, $image, $resid)
};

declare function iiif:Structures($item, $iiifroot){
 let $items := $item//t:msItem[.//t:locus][.//t:title[@ref]]
       let $collation := $item//t:collation/t:list/t:item[.//t:locus]
       let $additions := $item//t:additions/t:list/t:item[.//t:locus]
       let $decorations := $item//t:decoNote[.//t:locus]
      
      let  $mainstructure := if ($items or $collation or $additions or $decorations) then (
      let $superRanges := 
      let $its := if ($items) then  $iiifroot || "/range/"|| "msItems" else ()
      let $colls := if ($collation) then  $iiifroot ||"/range/"|| "quires" else ()
      let $adds := if ($additions) then  $iiifroot ||"/range/"|| "additions" else ()
      let $decs := if ($decorations) then  $iiifroot ||"/range/"|| "decorations" else ()
      return ($its, $colls, $adds, $decs)
      return
      map {"@context":= "http://iiif.io/api/presentation/2/context.json",
      "@id":$iiifroot ||"/range/"|| "main",
      "@type":"sc:Range",
      "label":"Table of Contents",
      "viewingHint":"top",
      "ranges" : $superRanges
    }) else ()
    
   let $msItemStructures :=  if($items) then
    let $ranges :=  <ranges>{for $msItem in $items return 
   <range>
    <r>{$iiifroot ||"/range/" || string($msItem/@xml:id)}</r>
    <t>{titles:printTitleID($msItem/t:title/@ref)}</t>
    {$msItem}
    </range>
    }
    </ranges>
    return
   iiif:rangeAndsubrange($iiifroot, $ranges, 'msItems', 'Contents') else ()

    
  let  $quiresStructures := 
   if($collation) then
    let $ranges :=  <ranges>{for $q in $collation return 
    <range>
    <r>{$iiifroot ||"/range/" || string($q/@xml:id)}</r>
    <t>{normalize-space(string-join($q/text(), ' ')|| ' (' ||$q/t:dim/text()||')')}</t>
    {$q}
    </range>}
    </ranges>
    return 
     iiif:rangeAndsubrange($iiifroot, $ranges, 'quires', 'Collation') else ()
 
   let  $additionsStructures := if($additions) then
    let $ranges :=  
    <ranges>{for $a  in $additions return 
    <range>
    <r>{$iiifroot ||"/range/" || string($a/@xml:id)}</r>
    <t>{string($a/t:desc/@type)}</t>
    {$a}
    </range>}
    </ranges>
   
    return
    iiif:rangeAndsubrange($iiifroot, $ranges, 'additions', 'Additions and Extras') else ()
    
     let  $decorationStructures := if($decorations) then
    let $ranges :=  
    <ranges>{  for $d in $decorations return
    <range>
    <r>{$iiifroot ||"/range/" || string($d/@xml:id)}</r>
    <t>{string($d/@type)}</t>
    {$d}
    </range>}
    </ranges>
    return
    
    iiif:rangeAndsubrange($iiifroot, $ranges, 'decorations', 'Decorations') else ()
  
  return
  ($mainstructure, $msItemStructures, $quiresStructures, $decorationStructures, $additionsStructures)
    
};

(:collection of all manifests available. this is called by rest viewer /manuscripts/viewer in the miradorcoll.js:)
     
        declare 
%rest:GET
%rest:path("/BetMas/api/iiif/collections")
%output:method("json")
function iiif:allManifests() {
($iiif:response200,
log:add-log-message('/api/iiif/collections', xmldb:get-current-user(), 'iiif'),
       
      let $allidno := collection($config:data-rootMS)//t:idno[@facs]
let $EMIP := $allidno[preceding-sibling::t:collection = 'EMIP'][@n]
let $ES := $allidno[preceding-sibling::t:collection = 'Ethio-SPaRe'][@n]
let $vat := $allidno[preceding-sibling::t:repository[@ref = 'INS0003BAV']]
let $bnf := $allidno[preceding-sibling::t:repository[@ref = 'INS0303BNF']]
let $filtered := ($ES, $EMIP, $vat, $bnf)
let $manifests := 
     for $images in $filtered
     let $this := $images/ancestor::t:TEI
     let $manifest := iiif:manifestsource($this)
         return
             map {'label' := titles:printTitleMainID($this/@xml:id) ,
      "@type": "sc:Manifest", 
      '@id' := $manifest}
 
 let $iiifroot := $config:appUrl ||"/api/iiif/"
(:       this is where the manifest is:)
       let $request := $iiifroot || "/collections"
        return
        map {
  "@context": "http://iiif.io/api/presentation/2/context.json",
  "@id": $request,
  "@type": "sc:Collection",
  "label": "Top Level Collection for " || $config:app-title,
  "viewingHint": "top",
  "description": "All images of Ethiopian Manuscripts available",
  "attribution": "Provided by BnF, Vatican Library, EthioSPaRe, EMIP and other IIIF providers",
  "manifests":  $manifests
   
  
}
       ) };


(:collection of all manifests available from one institution. this is called by rest viewer /manuscripts/{$repoid}/list/viewer in the miradorcoll.js:)

    declare 
%rest:GET
%rest:path("/BetMas/api/iiif/collection/{$institutionid}")
%output:method("json")
function iiif:RepoCollection($institutionid as xs:string) {
($iiif:response200,

log:add-log-message('/api/iiif/collections/' || $institutionid, xmldb:get-current-user(), 'iiif'),
let $repoName := titles:printTitleMainID($institutionid)
let $repo := collection($config:data-rootMS)//t:repository[@ref = $institutionid]
let $mswithimages := if($institutionid='INS0447EMIP') then $repo[following-sibling::t:idno[@facs][@n]] else $repo[following-sibling::t:idno[@facs]]
let $manifests :=
for $images in $mswithimages
let $this := $images/ancestor::t:TEI
let $idno := $images/following-sibling::t:idno[@facs]
     let $manifest := iiif:manifestsource($this)
         return
             map {'label' := titles:printTitleMainID($this/@xml:id) ,
      "@type": "sc:Manifest", 
      '@id' := $manifest}

 let $iiifroot := $config:appUrl ||"/api/iiif/"
(:       this is where the manifest is:)
       let $request := $iiifroot || "/collections"
 
        
        return
        map {
  "@context": "http://iiif.io/api/presentation/2/context.json",
  "@id": $request,
  "@type": "sc:Collection",
  "label": "Ethiopian Manuscripts at "  || $repoName,
  "viewingHint": "top",
  "description": "All images of Ethiopian Manuscripts available",
  "attribution": "Provided by " || $repoName,
  "manifests":  $manifests
   
  
}
      )  };


    declare 
%rest:GET
%rest:path("/BetMas/api/iiif/witnesses/{$workID}")
%output:method("json")
function iiif:WitnessesCollection($workID as xs:string) {
($iiif:response200,

log:add-log-message('/api/iiif/witnesses/' || $workID, xmldb:get-current-user(), 'iiif'),
let $workName := titles:printTitleMainID($workID)
let $work := collection($config:data-rootW)//id($workID)
let $mswithimages := $work//t:witness[@corresp]
let $externalmswithimages := $work//t:witness[@facs][t:ptr/@target]
let $listmanifests :=
(for $images in $mswithimages
let $msid := $images/@corresp
let $ms := collection($config:data-rootMS)//id($msid)
return
if($ms//t:idno[@facs]) then

let $manifest := iiif:manifestsource($ms)
         return
             map {'label' := titles:printTitleMainID($msid)  ,
      "@type": "sc:Manifest", 
      '@id' := $manifest}
   else (),
for $images in $externalmswithimages
let $this := concat($images/@corresp, ': ', $images/text(), ' [', $images/@facs, ']')
let $manifest := string($images/t:ptr/@target)
         return
             map {'label' := $this ,
      "@type": "sc:Manifest", 
      '@id' := $manifest}
      )
let $manifests := if(count($listmanifests) eq 1) then [$listmanifests] else $listmanifests
 let $iiifroot := $config:appUrl ||"/api/iiif/"
(:       this is where the manifest is:)
       let $request := $iiifroot || "/collections"
 
        
        return
        map {
  "@context": "http://iiif.io/api/presentation/2/context.json",
  "@id": $request,
  "@type": "sc:Collection",
  "label": "Manuscript witnesses of "  || $workName,
  "viewingHint": "top",
  "description": "All available images of witnesses",
  "attribution": "Provided by various institutions, see each manifest",
  "manifests":  $manifests
   
  
}
      )  };


(:manifest for one manuscript, including all ranges and canvases:)
(:IIIF: The manifest response contains sufficient information for the client to initialize itself and begin to display something quickly to the user. The manifest resource represents a single object and any intellectual work or works embodied within that object. In particular it includes the descriptive, rights and linking information for the object. It then embeds the sequence(s) of canvases that should be rendered to the user.:)
declare 
%rest:GET
%rest:path("/BetMas/api/iiif/{$id}/manifest")
%output:method("json") 
function iiif:manifest($id as xs:string*) {
let $item := if (starts-with($id, 'ES')) then collection($config:data-rootMS || '/ES')//id($id) else 
collection($config:data-rootMS || '/EMIP')//id($id)
       return
       if($item//t:msIdentifier/t:idno/@facs) then
($iiif:response200,

log:add-log-message('/api/iiif/'||$id||'/manifest', xmldb:get-current-user(), 'iiif'),
       (:let $item := collection($config:data-rootMS || '/ES')//id($id)
       :)let $institution := titles:printTitleMainID($item//t:repository/@ref)
       let $institutionID := string($item//t:repository/@ref)
       let $imagesbaseurl := $config:appUrl ||'/iiif/' || string($item//t:msIdentifier/t:idno/@facs)
       let $tot := $item//t:msIdentifier/t:idno/@n
       let $url :=  $config:appUrl ||"/manuscripts/" || $id
      (:       this is where the images actually are, in the images server:)
       let $thumbid := $imagesbaseurl ||(if($item//t:collection='EMIP') then () else '_') || '001.tif/full/80,100/0/default.jpg'
       let $objectType := string($item//@form[1])
       let $iiifroot := $config:appUrl ||"/api/iiif/" || $id
       let $image := $config:appUrl ||'/iiif/'||$id||'/'
       let $canvas := iiif:Canvases($item, $id, $iiifroot)
       let $structures := iiif:Structures($item, $iiifroot)
(:       this is where the manifest is:)
       let $request := $iiifroot || "/manifest"
       (:       this is where the sequence is:)
       let $attribution := "Provided by "||$item//t:collection/text()||" project."
       let $logo := "/rest/BetMas/resources/images/logo"||$item//t:collection/text()||".png"
       let $sequence := $iiifroot || "/sequence/normal"
     
     
(:    $mainstructure:)
return 
map {"@context":= "http://iiif.io/api/presentation/2/context.json",
  "@id": $request,
  "@type": "sc:Manifest",
  "label": titles:printTitleMainID($id),
  "metadata": [
    map {"label": "Repository", 
                "value": [
                  map   {"@value": $institution, "@language": "en"}
                            ]
      }, 
      map {"label": "object type", 
                "value": [
                  map   {"@value": $objectType, "@language": "en"}
                            ]
      }
      ],
      "description" : "An Ethiopian Manuscript.",
      
    "viewingDirection": "right-to-left",
  "viewingHint": "paged",
  "license": "http://creativecommons.org/licenses/by-nc-nd/4.0/",
  "attribution": $attribution,
  "logo": map {
    "@id": $config:appUrl || $logo
    },
"rendering": map {
    "@id": $url,
    "label": "web presentation",
    "format": "text/html"
  },
  "within": $config:appUrl ||"/manuscripts/list",

  "sequences": [ 
   map   {"@context": "http://iiif.io/api/presentation/2/context.json",
        "@id": $sequence,
        "@type": "sc:Sequence",
        "label": "Current Page Order",
  "viewingDirection": "left-to-right",
  "viewingHint": "paged",
  "canvases": $canvas
       }
      ],
  "structures": $structures
    }
    )
    else 
      ($iiif:response400,
       
       map{'info':= ('no manifest available for ' || $id )}
   )
};



(:dereferencable sequence The sequence conveys the ordering of the views of the object.:)
declare 
%rest:GET
%rest:path("/BetMas/api/iiif/{$id}/sequence/normal")
%output:method("json")
function iiif:sequence($id as xs:string*) {
($iiif:response200,

log:add-log-message('/api/iiif/'||$id||'/sequence/normal', xmldb:get-current-user(), 'iiif'),
        let $item := collection($config:data-rootMS || '/ES')//id($id)

let $iiifroot := $config:appUrl ||"/api/iiif/" || $id
let $sequence := $iiifroot || "/sequence/normal"
let $startCanvas := $iiifroot || '/canvas/p1'

let $canvas := iiif:Canvases($item, $id, $iiifroot)

       return
       
       map{"@context": "http://iiif.io/api/presentation/2/context.json",
  "@id": $sequence,
  "@type": "sc:Sequence",
  "label": "Current Page Order",
  "viewingDirection": "left-to-right",
  "viewingHint": "paged",
  "startCanvas": $startCanvas,
  "canvases": $canvas}
       )};
       
       
(:   dereference    canvas:)

(:IIIF: The canvas represents an individual page or view and acts as a central point for laying out the different content resources that make up the display. :)
       declare 
%rest:GET
%rest:path("/BetMas/api/iiif/{$id}/canvas/p{$n}")
%output:method("json")
function iiif:canvas($id as xs:string*, $n as xs:string*) {
($iiif:response200,

log:add-log-message('/api/iiif/'||$id||'/canvas/p' || $n, xmldb:get-current-user(), 'iiif'),
let $item := collection($config:data-rootMS || '/ES')//id($id)
let $iiifroot := $config:appUrl ||"/api/iiif/" || $id 
let $imagesbaseurl := $config:appUrl ||'/iiif/' || string($item//t:msIdentifier/t:idno/@facs)
 let $imagefile := format-number($n, '000') || '.tif'
let $resid := ($imagesbaseurl || (if($item//t:collection='EMIP') then () else '_') || $imagefile )
 let $image := ($imagesbaseurl || (if($item//t:collection='EMIP') then () else '_') || $imagefile || '/full/full/0/default.jpg' )
let $name := string($n)
let $id := $iiifroot || '/canvas/p'  || $n
       return
       iiif:oneCanvas($id, $name, $image, $resid)
      ) };
       
       
       

        
(:    IIIF Documentation:   
It may be important to describe additional structure within an object, 
such as newspaper articles that span pages, the range of 
non-content-bearing pages at the beginning of a work, 
or chapters within a book. These are described using ranges in a similar manner to sequences.:)
        (: There is no need to dereference this at the moment.
        each msItem, quire, addition and decoration have an id which is used as name for the range and in the function is called n:)

   (:     declare 
%rest:GET
%rest:path("/BetMas/api/iiif/{$id}/range/{$name}/{$id}")
%output:method("json")
function iiif:range($id as xs:string*, $name as xs:string*, $id as xs:string?) {
<rest:response>
            <http:response
                status="200">
                <http:header
                    name="Content-Type"
                    value="application/json; charset=utf-8"/>
            </http:response>
        </rest:response>,
        let $item := collection($config:data-root)//id($id)(\:       image Resource:\)
        return
        $id
        };:)
        
        
        
(:        layer  IIIF: Layers represent groupings of 
annotation lists that should be collected together, regardless of which canvas they target, such as all of the annotations that make up a particular translation of the text of a book. Without the layer construction, it would be impossible to determine which annotations belonged together across canvases. A client might then present a user interface that allows all of the annotations in a layer to be displayed or hidden according to the user’s preference.

:)

  
(:       image Resource
it is not possible to go back from annotation number to the canvas number, thus dereferincing this annotation is not possible
:)
(:        declare 
%rest:GET
%rest:path("/BetMas/api/iiif/{$id}/annotation/p{$n}-image")
%output:method("json")
function iiif:annotation($id as xs:string*, $n as xs:string*) {
($iiif:response200,
        let $item := collection($config:data-root)//id($id)
       let $imagesbaseurl := 'http://betamasaheft.aai.uni-hamburg.de/iiif/' || string($item//t:msIdentifier/t:idno/@facs)
 let $imagefile := format-number($n, '000') || '.tif'
let $resid := ($imagesbaseurl || '_' || $imagefile )
 let $image := ($imagesbaseurl || '_' || $imagefile || '/full/full/0/default.jpg' )
let $id := $iiifroot || '/canvas/p'  || $n
       return
     iiif:annotation($id, $image, $resid)
    )   };
       :)
       
       
(:      annotations list IIIF documentation: 
For some objects, there may be more than just images available to represent the page. 
Other resources could include the full text of the object, musical notations, musical performances, 
diagram transcriptions, commentary annotations, tags, video, data and more. 
These additional resources are included in annotation lists, referenced from the canvas they are associated with.:)


(:there is no need at the moment for lists of annotations
:)
  (:declare 
%rest:GET
%rest:path("/BetMas/api/iiif/{$id}/list/p{$n}")
%output:method("json")
function iiif:list($id as xs:string*, $n as xs:string*) {
<rest:response>
            <http:response
                status="200">
                <http:header
                    name="Content-Type"
                    value="application/json; charset=utf-8"/>
            </http:response>
        </rest:response>,
        let $item := collection($config:data-root)//id($id)
        
        return
        $id
        };
        :)
        
        (:
        
        declare 
%rest:GET
%rest:path("/BetMas/api/iiif/{$id}/layer/{$n}")
%output:method("json")
function iiif:layer($id as xs:string*, $n as xs:string*) {
<rest:response>
            <http:response
                status="200">
                <http:header
                    name="Content-Type"
                    value="application/json; charset=utf-8"/>
            </http:response>
        </rest:response>,
        let $item := collection($config:data-root)//id($id)
        
        return
        $id
        };
:)
   

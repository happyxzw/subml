<!DOCTYPE html>
<html>
<head>
  <title>SubML language</title>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="https://code.jquery.com/ui/1.11.4/themes/smoothness/jquery-ui.css">
  <link rel="stylesheet" href="lib/codemirror.css">
  <link rel="stylesheet" href="theme/solarized.css">
  <link rel="stylesheet" href="addon/scroll/simplescrollbars.css">
  <script src="lib/codemirror.js"></script>
  <script src="mode/subml/subml.js"></script>
  <script src="addon/scroll/simplescrollbars.js"></script>
  <script src="https://code.jquery.com/jquery-1.10.2.js"></script>
  <script src="https://code.jquery.com/ui/1.11.4/jquery-ui.js"></script>
  <link rel="stylesheet" href="style.css">
  <script src="script.js"></script>
</head>
<body>
  <div id="west">
    <div id="edit"></div>
    <div id="panel">
      <p id="pos"></p>
      <a href="javascript:subml_eval()">Load</a>
      <a href="javascript:term.setValue('')">Clear log</a>
      <a href="javascript:edit.setValue('')">Clear editor</a>
    </div>
    <div id="term"></div>
  </div>
  <div id="east">
    <div id="text">
      <h1>SubML (prototype) language</h1>
      <p>
        The SubML language implements the type system presented in the paper
        <q><a href="docs/subml.pdf">Subtyping-Based Type-Checking for
        System F with Induction and Coinduction</a></q>. In this paper,
        <a href="http://lama.univ-savoie.fr/~lepigre">Rodolphe Lepigre</a> and
        <a href="http://lama.univ-savoie.fr/~raffalli">Christophe Raffalli</a>
        argue that it is possible to build a practical type systems based on
        subtyping for extensions of
        <a href="https://en.wikipedia.org/wiki/System_F">System F</a>. The
        SubML language provides polymorphic types and subtyping, but also
        existential types, inductive types and coinductive types. Usual
        programming in the style of ML is also supported using sum types and
        product types corresponding to polymorphic variants and records. The
        system can be used on this webpage as explained bellow, or downloaded
        and and compiled from its OCaml <a href="docs/subml-latest.tar.gz">source code</a>.
      </p>
      <h2>Tutorial and online interpreter</h2>
      <p>
        The SubML language can be tried on this webpage, using the editor on
        the lefthand side. The syntax of the language is exhibited in the
        <a class="submlfile" href="javascript:loadsubmlfile('tutorial.typ')">tutorial</a>
        that is loaded in the editor by default. Other examples marked by
        yellow links can be loaded into the editor at any time. In particular,
        the <a class="submlfile" href="javascript:loadsubmlfile('lib/prelude.typ')">prelude</a>
        is automatically loaded into the interpreter. The standard library of
        SubML includes <a class="submlfile" href="javascript:loadsubmlfile('lib/nat.typ')">unary natural numbers</a>
        (lib/nat.typ), <a class="submlfile" href="javascript:loadsubmlfile('lib/list.typ')">lists</a>
        (lib/list.typ) and <a class="submlfile" href="javascript:loadsubmlfile('lib/set.typ')">sets</a>
        (lib/set.typ) implemented using binary search trees. A library for
        <a class="submlfile" href="javascript:loadsubmlfile('lib/applist.typ')">append lists</a>
        (lib/applist.typ) with constant time append operation is also provided.
        The type of append lists is a supertype of the type of lists. Other
        advanced examples expoiting subtyping are given in the example section
        below.
      </p>
      <h2>Advanced examples</h2>
      <?php include 'examples.html'; ?>
    </div>
  </div>
</body>
</html>
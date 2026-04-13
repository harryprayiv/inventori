{ inputs, purs-nix-instance, ps-pkgs }:

let
  build = purs-nix-instance.build;

  hyrule = build {
    name = "hyrule";
    src.path = inputs.purescript-hyrule;
    info.dependencies = with ps-pkgs; [
      avar effect filterable free js-timers random
      web-html unsafe-reference web-uievents
    ];
  };

  deku-core = build {
    name = "deku-core";
    src.path = inputs.purescript-deku + "/deku-core";
    info.dependencies = with ps-pkgs; [ untagged-union ] ++ [ hyrule ];
  };

  deku-dom = build {
    name = "deku-dom";
    src.path = inputs.purescript-deku + "/deku-dom";
    info.dependencies = with ps-pkgs; [
      web-touchevents web-pointerevents untagged-union
    ] ++ [ hyrule ];
  };

in with ps-pkgs; [
  # direct deps from spago.yaml
  aff
  aff-promise
  arrays
  console
  effect
  either
  fetch
  foldable-traversable
  foreign-object
  integers
  lists
  maybe
  newtype
  now
  ordered-collections
  prelude
  strings
  tuples
  unsafe-coerce
  web-dom
  web-events
  web-file
  web-html
  web-storage
  yoga-json

  # transitive deps for custom builds
  avar
  filterable
  free
  js-timers
  random
  unsafe-reference
  untagged-union
  web-pointerevents
  web-touchevents
  web-uievents

  # custom builds
  hyrule
  deku-core
  deku-dom
]
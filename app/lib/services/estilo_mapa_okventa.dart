// Estilo del mapa vectorial de OkVenta (modo "noche": azul marino con
// calles celestes y nombres en blanco). Generado a partir de OSM Liberty
// (licencia BSD; diseño CC-BY 3.0, datos © OpenMapTiles © OpenStreetMap)
// y recoloreado. Para cambiar colores, editar aquí (formato estilo
// MapLibre/Mapbox GL, esquema OpenMapTiles).
//
// ignore_for_file: lines_longer_than_80_chars
const String estiloMapaOkventaNoche = '''
{
 "version": 8,
 "name": "OkVenta Noche",
 "metadata": {
  "version": "1",
  "base": "OSM Liberty (BSD/CC-BY), recoloreado para OkVenta"
 },
 "sources": {
  "openmaptiles": {
   "type": "vector"
  }
 },
 "layers": [
  {
   "id": "background",
   "type": "background",
   "paint": {
    "background-color": "#13213A"
   }
  },
  {
   "id": "park",
   "type": "fill",
   "source": "openmaptiles",
   "source-layer": "park",
   "paint": {
    "fill-color": "#1B3238",
    "fill-opacity": 0.7,
    "fill-outline-color": "#24423F"
   }
  },
  {
   "id": "park_outline",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "park",
   "paint": {
    "line-dasharray": [
     1,
     1.5
    ],
    "line-color": "#24423F"
   }
  },
  {
   "id": "landuse_residential",
   "type": "fill",
   "source": "openmaptiles",
   "source-layer": "landuse",
   "maxzoom": 8,
   "filter": [
    "==",
    "class",
    "residential"
   ],
   "paint": {
    "fill-color": "rgba(28,46,78,0.55)"
   }
  },
  {
   "id": "landcover_wood",
   "type": "fill",
   "source": "openmaptiles",
   "source-layer": "landcover",
   "filter": [
    "all",
    [
     "==",
     "class",
     "wood"
    ]
   ],
   "paint": {
    "fill-antialias": false,
    "fill-color": "rgba(27,52,56,0.8)",
    "fill-opacity": 0.4
   }
  },
  {
   "id": "landcover_grass",
   "type": "fill",
   "source": "openmaptiles",
   "source-layer": "landcover",
   "filter": [
    "all",
    [
     "==",
     "class",
     "grass"
    ]
   ],
   "paint": {
    "fill-antialias": false,
    "fill-color": "#1B3238",
    "fill-opacity": 0.3
   }
  },
  {
   "id": "landuse_cemetery",
   "type": "fill",
   "source": "openmaptiles",
   "source-layer": "landuse",
   "filter": [
    "==",
    "class",
    "cemetery"
   ],
   "paint": {
    "fill-color": "#1B3238"
   }
  },
  {
   "id": "waterway_tunnel",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "waterway",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ]
   ],
   "paint": {
    "line-color": "#2B5C9E",
    "line-dasharray": [
     3,
     3
    ],
    "line-gap-width": {
     "stops": [
      [
       12,
       0
      ],
      [
       20,
       6
      ]
     ]
    },
    "line-opacity": 1,
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       8,
       1
      ],
      [
       20,
       2
      ]
     ]
    }
   }
  },
  {
   "id": "waterway_river",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "waterway",
   "filter": [
    "all",
    [
     "==",
     "class",
     "river"
    ],
    [
     "!=",
     "brunnel",
     "tunnel"
    ]
   ],
   "layout": {
    "line-cap": "round"
   },
   "paint": {
    "line-color": "#2B5C9E",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       11,
       0.5
      ],
      [
       20,
       6
      ]
     ]
    }
   }
  },
  {
   "id": "waterway_other",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "waterway",
   "filter": [
    "all",
    [
     "!=",
     "class",
     "river"
    ],
    [
     "!=",
     "brunnel",
     "tunnel"
    ]
   ],
   "layout": {
    "line-cap": "round"
   },
   "paint": {
    "line-color": "#2B5C9E",
    "line-width": {
     "base": 1.3,
     "stops": [
      [
       13,
       0.5
      ],
      [
       20,
       6
      ]
     ]
    }
   }
  },
  {
   "id": "water",
   "type": "fill",
   "source": "openmaptiles",
   "source-layer": "water",
   "filter": [
    "all",
    [
     "!=",
     "brunnel",
     "tunnel"
    ]
   ],
   "paint": {
    "fill-color": "#0A1426"
   }
  },
  {
   "id": "aeroway_fill",
   "type": "fill",
   "source": "openmaptiles",
   "source-layer": "aeroway",
   "minzoom": 11,
   "filter": [
    "==",
    "\$type",
    "Polygon"
   ],
   "paint": {
    "fill-color": "#18294A",
    "fill-opacity": 0.7
   }
  },
  {
   "id": "aeroway_runway",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "aeroway",
   "minzoom": 11,
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "LineString"
    ],
    [
     "==",
     "class",
     "runway"
    ]
   ],
   "paint": {
    "line-color": "#2A4166",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       11,
       3
      ],
      [
       20,
       16
      ]
     ]
    }
   }
  },
  {
   "id": "aeroway_taxiway",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "aeroway",
   "minzoom": 11,
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "LineString"
    ],
    [
     "==",
     "class",
     "taxiway"
    ]
   ],
   "paint": {
    "line-color": "#2A4166",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       11,
       0.5
      ],
      [
       20,
       6
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_motorway_link_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "==",
     "ramp",
     1
    ],
    [
     "==",
     "brunnel",
     "tunnel"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-dasharray": [
     0.5,
     0.25
    ],
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12,
       1
      ],
      [
       13,
       3
      ],
      [
       14,
       4
      ],
      [
       20,
       15
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_service_track_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "service",
     "track"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#0D1830",
    "line-dasharray": [
     0.5,
     0.25
    ],
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       15,
       1
      ],
      [
       16,
       4
      ],
      [
       20,
       11
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_link_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "ramp",
     1
    ],
    [
     "==",
     "brunnel",
     "tunnel"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12,
       1
      ],
      [
       13,
       3
      ],
      [
       14,
       4
      ],
      [
       20,
       15
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_street_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "street",
     "street_limited"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#0D1830",
    "line-opacity": {
     "stops": [
      [
       12,
       0
      ],
      [
       12.5,
       1
      ]
     ]
    },
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12,
       0.5
      ],
      [
       13,
       1
      ],
      [
       14,
       4
      ],
      [
       20,
       15
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_secondary_tertiary_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "secondary",
     "tertiary"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       8,
       1.5
      ],
      [
       20,
       17
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_trunk_primary_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "primary",
     "trunk"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0.4
      ],
      [
       6,
       0.7
      ],
      [
       7,
       1.75
      ],
      [
       20,
       22
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_motorway_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "!=",
     "ramp",
     1
    ],
    [
     "==",
     "brunnel",
     "tunnel"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-dasharray": [
     0.5,
     0.25
    ],
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0.4
      ],
      [
       6,
       0.7
      ],
      [
       7,
       1.75
      ],
      [
       20,
       22
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_path_pedestrian",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "LineString"
    ],
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "path",
     "pedestrian"
    ]
   ],
   "paint": {
    "line-color": "#2A4877",
    "line-dasharray": [
     1,
     0.75
    ],
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       14,
       0.5
      ],
      [
       20,
       10
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_motorway_link",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "==",
     "ramp",
     1
    ],
    [
     "==",
     "brunnel",
     "tunnel"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#A3CCFF",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12.5,
       0
      ],
      [
       13,
       1.5
      ],
      [
       14,
       2.5
      ],
      [
       20,
       11.5
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_service_track",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "service",
     "track"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#2F5591",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       15.5,
       0
      ],
      [
       16,
       2
      ],
      [
       20,
       7.5
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_link",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "ramp",
     1
    ],
    [
     "==",
     "brunnel",
     "tunnel"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#5A8FD8",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12.5,
       0
      ],
      [
       13,
       1.5
      ],
      [
       14,
       2.5
      ],
      [
       20,
       11.5
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_minor",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "minor"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#3E6FB6",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       13.5,
       0
      ],
      [
       14,
       2.5
      ],
      [
       20,
       11.5
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_secondary_tertiary",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "secondary",
     "tertiary"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#5A8FD8",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       6.5,
       0
      ],
      [
       7,
       0.5
      ],
      [
       20,
       10
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_trunk_primary",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "primary",
     "trunk"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#7DB0F2",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0
      ],
      [
       7,
       1
      ],
      [
       20,
       18
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_motorway",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "!=",
     "ramp",
     1
    ],
    [
     "==",
     "brunnel",
     "tunnel"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#A3CCFF",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0
      ],
      [
       7,
       1
      ],
      [
       20,
       18
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_major_rail",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "rail"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14,
       0.4
      ],
      [
       15,
       0.75
      ],
      [
       20,
       2
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_major_rail_hatching",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "==",
     "class",
     "rail"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-dasharray": [
     0.2,
     8
    ],
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14.5,
       0
      ],
      [
       15,
       3
      ],
      [
       20,
       8
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_transit_rail",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "in",
     "class",
     "transit"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14,
       0.4
      ],
      [
       15,
       0.75
      ],
      [
       20,
       2
      ]
     ]
    }
   }
  },
  {
   "id": "tunnel_transit_rail_hatching",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "tunnel"
    ],
    [
     "==",
     "class",
     "transit"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-dasharray": [
     0.2,
     8
    ],
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14.5,
       0
      ],
      [
       15,
       3
      ],
      [
       20,
       8
      ]
     ]
    }
   }
  },
  {
   "id": "road_motorway_link_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "minzoom": 12,
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "==",
     "ramp",
     1
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12,
       1
      ],
      [
       13,
       3
      ],
      [
       14,
       4
      ],
      [
       20,
       15
      ]
     ]
    }
   }
  },
  {
   "id": "road_service_track_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "in",
     "class",
     "service",
     "track"
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#0D1830",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       15,
       1
      ],
      [
       16,
       4
      ],
      [
       20,
       11
      ]
     ]
    }
   }
  },
  {
   "id": "road_link_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "minzoom": 13,
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "!in",
     "class",
     "pedestrian",
     "path",
     "track",
     "service",
     "motorway"
    ],
    [
     "==",
     "ramp",
     1
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12,
       1
      ],
      [
       13,
       3
      ],
      [
       14,
       4
      ],
      [
       20,
       15
      ]
     ]
    }
   }
  },
  {
   "id": "road_minor_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "LineString"
    ],
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "in",
     "class",
     "minor"
    ],
    [
     "!=",
     "ramp",
     1
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#0D1830",
    "line-opacity": {
     "stops": [
      [
       12,
       0
      ],
      [
       12.5,
       1
      ]
     ]
    },
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12,
       0.5
      ],
      [
       13,
       1
      ],
      [
       14,
       4
      ],
      [
       20,
       20
      ]
     ]
    }
   }
  },
  {
   "id": "road_secondary_tertiary_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "in",
     "class",
     "secondary",
     "tertiary"
    ],
    [
     "!=",
     "ramp",
     1
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       8,
       1.5
      ],
      [
       20,
       17
      ]
     ]
    }
   }
  },
  {
   "id": "road_trunk_primary_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "in",
     "class",
     "primary",
     "trunk"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0.4
      ],
      [
       6,
       0.7
      ],
      [
       7,
       1.75
      ],
      [
       20,
       22
      ]
     ]
    }
   }
  },
  {
   "id": "road_motorway_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "minzoom": 5,
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "!=",
     "ramp",
     1
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0.4
      ],
      [
       6,
       0.7
      ],
      [
       7,
       1.75
      ],
      [
       20,
       22
      ]
     ]
    }
   }
  },
  {
   "id": "road_path_pedestrian",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "minzoom": 14,
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "LineString"
    ],
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "in",
     "class",
     "path",
     "pedestrian"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#2A4877",
    "line-dasharray": [
     1,
     0.7
    ],
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       14,
       1
      ],
      [
       20,
       10
      ]
     ]
    }
   }
  },
  {
   "id": "road_motorway_link",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "minzoom": 12,
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "==",
     "ramp",
     1
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#A3CCFF",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12.5,
       0
      ],
      [
       13,
       1.5
      ],
      [
       14,
       2.5
      ],
      [
       20,
       11.5
      ]
     ]
    }
   }
  },
  {
   "id": "road_service_track",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "in",
     "class",
     "service",
     "track"
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#2F5591",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       15.5,
       0
      ],
      [
       16,
       2
      ],
      [
       20,
       7.5
      ]
     ]
    }
   }
  },
  {
   "id": "road_link",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "minzoom": 13,
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "==",
     "ramp",
     1
    ],
    [
     "!in",
     "class",
     "pedestrian",
     "path",
     "track",
     "service",
     "motorway"
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#5A8FD8",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12.5,
       0
      ],
      [
       13,
       1.5
      ],
      [
       14,
       2.5
      ],
      [
       20,
       11.5
      ]
     ]
    }
   }
  },
  {
   "id": "road_minor",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "LineString"
    ],
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "in",
     "class",
     "minor"
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#3E6FB6",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       13.5,
       0
      ],
      [
       14,
       2.5
      ],
      [
       20,
       18
      ]
     ]
    }
   }
  },
  {
   "id": "road_secondary_tertiary",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "in",
     "class",
     "secondary",
     "tertiary"
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#5A8FD8",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       6.5,
       0
      ],
      [
       8,
       0.5
      ],
      [
       20,
       13
      ]
     ]
    }
   }
  },
  {
   "id": "road_trunk_primary",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "in",
     "class",
     "primary",
     "trunk"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#7DB0F2",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0
      ],
      [
       7,
       1
      ],
      [
       20,
       18
      ]
     ]
    }
   }
  },
  {
   "id": "road_motorway",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "minzoom": 5,
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "!=",
     "ramp",
     1
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#A3CCFF",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0
      ],
      [
       7,
       1
      ],
      [
       20,
       18
      ]
     ]
    }
   }
  },
  {
   "id": "road_major_rail",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "==",
     "class",
     "rail"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14,
       0.4
      ],
      [
       15,
       0.75
      ],
      [
       20,
       2
      ]
     ]
    }
   }
  },
  {
   "id": "road_major_rail_hatching",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "==",
     "class",
     "rail"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-dasharray": [
     0.2,
     8
    ],
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14.5,
       0
      ],
      [
       15,
       3
      ],
      [
       20,
       8
      ]
     ]
    }
   }
  },
  {
   "id": "road_transit_rail",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "==",
     "class",
     "transit"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14,
       0.4
      ],
      [
       15,
       0.75
      ],
      [
       20,
       2
      ]
     ]
    }
   }
  },
  {
   "id": "road_transit_rail_hatching",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "!in",
     "brunnel",
     "bridge",
     "tunnel"
    ],
    [
     "==",
     "class",
     "transit"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-dasharray": [
     0.2,
     8
    ],
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14.5,
       0
      ],
      [
       15,
       3
      ],
      [
       20,
       8
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_motorway_link_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "==",
     "ramp",
     1
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12,
       1
      ],
      [
       13,
       3
      ],
      [
       14,
       4
      ],
      [
       20,
       15
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_service_track_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "bridge"
    ],
    [
     "in",
     "class",
     "service",
     "track"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#0D1830",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       15,
       1
      ],
      [
       16,
       4
      ],
      [
       20,
       11
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_link_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "link"
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12,
       1
      ],
      [
       13,
       3
      ],
      [
       14,
       4
      ],
      [
       20,
       15
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_street_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "bridge"
    ],
    [
     "in",
     "class",
     "street",
     "street_limited"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#0D1830",
    "line-opacity": {
     "stops": [
      [
       12,
       0
      ],
      [
       12.5,
       1
      ]
     ]
    },
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12,
       0.5
      ],
      [
       13,
       1
      ],
      [
       14,
       4
      ],
      [
       20,
       25
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_path_pedestrian_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "LineString"
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ],
    [
     "in",
     "class",
     "path",
     "pedestrian"
    ]
   ],
   "paint": {
    "line-color": "#0D1830",
    "line-dasharray": [
     1,
     0
    ],
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       14,
       1.5
      ],
      [
       20,
       18
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_secondary_tertiary_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "bridge"
    ],
    [
     "in",
     "class",
     "secondary",
     "tertiary"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       8,
       1.5
      ],
      [
       20,
       17
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_trunk_primary_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "bridge"
    ],
    [
     "in",
     "class",
     "primary",
     "trunk"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0.4
      ],
      [
       6,
       0.7
      ],
      [
       7,
       1.75
      ],
      [
       20,
       22
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_motorway_casing",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "!=",
     "ramp",
     1
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#1B3866",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0.4
      ],
      [
       6,
       0.7
      ],
      [
       7,
       1.75
      ],
      [
       20,
       22
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_path_pedestrian",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "LineString"
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ],
    [
     "in",
     "class",
     "path",
     "pedestrian"
    ]
   ],
   "paint": {
    "line-color": "#2A4877",
    "line-dasharray": [
     1,
     0.3
    ],
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       14,
       0.5
      ],
      [
       20,
       10
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_motorway_link",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "==",
     "ramp",
     1
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#A3CCFF",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12.5,
       0
      ],
      [
       13,
       1.5
      ],
      [
       14,
       2.5
      ],
      [
       20,
       11.5
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_service_track",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "bridge"
    ],
    [
     "in",
     "class",
     "service",
     "track"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#2F5591",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       15.5,
       0
      ],
      [
       16,
       2
      ],
      [
       20,
       7.5
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_link",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "link"
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#5A8FD8",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       12.5,
       0
      ],
      [
       13,
       1.5
      ],
      [
       14,
       2.5
      ],
      [
       20,
       11.5
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_street",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "bridge"
    ],
    [
     "in",
     "class",
     "minor"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#3E6FB6",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       13.5,
       0
      ],
      [
       14,
       2.5
      ],
      [
       20,
       18
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_secondary_tertiary",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "bridge"
    ],
    [
     "in",
     "class",
     "secondary",
     "tertiary"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#5A8FD8",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       6.5,
       0
      ],
      [
       7,
       0.5
      ],
      [
       20,
       10
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_trunk_primary",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "brunnel",
     "bridge"
    ],
    [
     "in",
     "class",
     "primary",
     "trunk"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#7DB0F2",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0
      ],
      [
       7,
       1
      ],
      [
       20,
       18
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_motorway",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "motorway"
    ],
    [
     "!=",
     "ramp",
     1
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#A3CCFF",
    "line-width": {
     "base": 1.2,
     "stops": [
      [
       5,
       0
      ],
      [
       7,
       1
      ],
      [
       20,
       18
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_major_rail",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "rail"
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14,
       0.4
      ],
      [
       15,
       0.75
      ],
      [
       20,
       2
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_major_rail_hatching",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "rail"
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-dasharray": [
     0.2,
     8
    ],
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14.5,
       0
      ],
      [
       15,
       3
      ],
      [
       20,
       8
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_transit_rail",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "transit"
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14,
       0.4
      ],
      [
       15,
       0.75
      ],
      [
       20,
       2
      ]
     ]
    }
   }
  },
  {
   "id": "bridge_transit_rail_hatching",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "transportation",
   "filter": [
    "all",
    [
     "==",
     "class",
     "transit"
    ],
    [
     "==",
     "brunnel",
     "bridge"
    ]
   ],
   "paint": {
    "line-color": "#34476B",
    "line-dasharray": [
     0.2,
     8
    ],
    "line-width": {
     "base": 1.4,
     "stops": [
      [
       14.5,
       0
      ],
      [
       15,
       3
      ],
      [
       20,
       8
      ]
     ]
    }
   }
  },
  {
   "id": "building",
   "type": "fill",
   "source": "openmaptiles",
   "source-layer": "building",
   "minzoom": 13,
   "maxzoom": 14,
   "paint": {
    "fill-color": "#0F1B31",
    "fill-outline-color": "#1D2F50"
   }
  },
  {
   "id": "boundary_3",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "boundary",
   "minzoom": 8,
   "filter": [
    "all",
    [
     "in",
     "admin_level",
     3,
     4
    ]
   ],
   "layout": {
    "line-join": "round"
   },
   "paint": {
    "line-color": "#4A5F86",
    "line-dasharray": [
     5,
     1
    ],
    "line-width": {
     "base": 1,
     "stops": [
      [
       4,
       0.4
      ],
      [
       5,
       1
      ],
      [
       12,
       1.8
      ]
     ]
    }
   }
  },
  {
   "id": "boundary_2_z0-4",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "boundary",
   "maxzoom": 5,
   "filter": [
    "all",
    [
     "==",
     "admin_level",
     2
    ],
    [
     "!has",
     "claimed_by"
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#5A6E96",
    "line-opacity": {
     "base": 1,
     "stops": [
      [
       0,
       0.4
      ],
      [
       4,
       1
      ]
     ]
    },
    "line-width": {
     "base": 1,
     "stops": [
      [
       3,
       1
      ],
      [
       5,
       1.2
      ],
      [
       12,
       3
      ]
     ]
    }
   }
  },
  {
   "id": "boundary_2_z5-",
   "type": "line",
   "source": "openmaptiles",
   "source-layer": "boundary",
   "minzoom": 5,
   "filter": [
    "all",
    [
     "==",
     "admin_level",
     2
    ]
   ],
   "layout": {
    "line-cap": "round",
    "line-join": "round"
   },
   "paint": {
    "line-color": "#5A6E96",
    "line-opacity": {
     "base": 1,
     "stops": [
      [
       0,
       0.4
      ],
      [
       4,
       1
      ]
     ]
    },
    "line-width": {
     "base": 1,
     "stops": [
      [
       3,
       1
      ],
      [
       5,
       1.2
      ],
      [
       12,
       3
      ]
     ]
    }
   }
  },
  {
   "id": "water_name_line",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "waterway",
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "LineString"
    ]
   ],
   "layout": {
    "text-field": "{name}",
    "text-font": [
     "Roboto Regular"
    ],
    "text-max-width": 5,
    "text-size": 12,
    "symbol-placement": "line"
   },
   "paint": {
    "text-color": "#6FA3E6",
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1
   }
  },
  {
   "id": "water_name_point",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "water_name",
   "filter": [
    "==",
    "\$type",
    "Point"
   ],
   "layout": {
    "text-field": "{name}",
    "text-font": [
     "Roboto Regular"
    ],
    "text-max-width": 5,
    "text-size": 12
   },
   "paint": {
    "text-color": "#6FA3E6",
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1
   }
  },
  {
   "id": "poi_z16",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "poi",
   "minzoom": 16,
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "Point"
    ],
    [
     ">=",
     "rank",
     20
    ]
   ],
   "layout": {
    "text-anchor": "center",
    "text-field": "{name}",
    "text-font": [
     "Roboto Condensed Italic"
    ],
    "text-max-width": 9,
    "text-size": 12
   },
   "paint": {
    "text-color": "#F2C46B",
    "text-halo-blur": 0.5,
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.2
   }
  },
  {
   "id": "poi_z15",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "poi",
   "minzoom": 15,
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "Point"
    ],
    [
     ">=",
     "rank",
     7
    ],
    [
     "<",
     "rank",
     20
    ]
   ],
   "layout": {
    "text-anchor": "center",
    "text-field": "{name}",
    "text-font": [
     "Roboto Condensed Italic"
    ],
    "text-max-width": 9,
    "text-size": 12
   },
   "paint": {
    "text-color": "#F2C46B",
    "text-halo-blur": 0.5,
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.2
   }
  },
  {
   "id": "poi_z14",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "poi",
   "minzoom": 14,
   "filter": [
    "all",
    [
     "==",
     "\$type",
     "Point"
    ],
    [
     ">=",
     "rank",
     1
    ],
    [
     "<",
     "rank",
     7
    ]
   ],
   "layout": {
    "text-anchor": "center",
    "text-field": "{name}",
    "text-font": [
     "Roboto Condensed Italic"
    ],
    "text-max-width": 9,
    "text-size": 12
   },
   "paint": {
    "text-color": "#F2C46B",
    "text-halo-blur": 0.5,
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.2
   }
  },
  {
   "id": "poi_transit",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "poi",
   "filter": [
    "all",
    [
     "in",
     "class",
     "bus",
     "rail",
     "airport"
    ]
   ],
   "layout": {
    "text-anchor": "center",
    "text-field": "{name}",
    "text-font": [
     "Roboto Condensed Italic"
    ],
    "text-max-width": 9,
    "text-size": 12
   },
   "paint": {
    "text-color": "#7FB8FF",
    "text-halo-blur": 0.5,
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.2
   }
  },
  {
   "id": "road_label",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "transportation_name",
   "filter": [
    "all"
   ],
   "layout": {
    "symbol-placement": "line",
    "text-anchor": "center",
    "text-field": "{name}",
    "text-font": [
     "Roboto Medium"
    ],
    "text-offset": [
     0,
     0.15
    ],
    "text-size": {
     "base": 1,
     "stops": [
      [
       13,
       12
      ],
      [
       15,
       13.5
      ],
      [
       17,
       15
      ]
     ]
    }
   },
   "paint": {
    "text-color": "#E3ECFF",
    "text-halo-blur": 0.5,
    "text-halo-width": 1.4,
    "text-halo-color": "rgba(13,24,48,0.92)"
   }
  },
  {
   "id": "place_other",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "place",
   "filter": [
    "all",
    [
     "in",
     "class",
     "hamlet",
     "island",
     "islet",
     "neighbourhood",
     "suburb"
    ]
   ],
   "layout": {
    "text-field": "{name}",
    "text-font": [
     "Roboto Condensed Italic"
    ],
    "text-letter-spacing": 0.1,
    "text-max-width": 9,
    "text-size": {
     "base": 1.2,
     "stops": [
      [
       12,
       10
      ],
      [
       15,
       14
      ]
     ]
    },
    "text-transform": "uppercase"
   },
   "paint": {
    "text-color": "#B9CCEB",
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.5
   }
  },
  {
   "id": "place_village",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "place",
   "filter": [
    "all",
    [
     "==",
     "class",
     "village"
    ]
   ],
   "layout": {
    "text-field": "{name}",
    "text-font": [
     "Roboto Regular"
    ],
    "text-max-width": 8,
    "text-size": {
     "base": 1.2,
     "stops": [
      [
       10,
       12
      ],
      [
       15,
       22
      ]
     ]
    }
   },
   "paint": {
    "text-color": "#FFFFFF",
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.5
   }
  },
  {
   "id": "place_town",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "place",
   "filter": [
    "all",
    [
     "==",
     "class",
     "town"
    ]
   ],
   "layout": {
    "text-anchor": "bottom",
    "text-field": "{name}",
    "text-font": [
     "Roboto Regular"
    ],
    "text-max-width": 8,
    "text-offset": [
     0,
     0
    ],
    "text-size": {
     "base": 1.2,
     "stops": [
      [
       7,
       12
      ],
      [
       11,
       16
      ]
     ]
    }
   },
   "paint": {
    "text-color": "#FFFFFF",
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.5
   }
  },
  {
   "id": "place_city",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "place",
   "minzoom": 5,
   "filter": [
    "all",
    [
     "==",
     "class",
     "city"
    ]
   ],
   "layout": {
    "text-anchor": "bottom",
    "text-field": "{name}",
    "text-font": [
     "Roboto Medium"
    ],
    "text-max-width": 8,
    "text-offset": [
     0,
     0
    ],
    "text-size": {
     "base": 1.2,
     "stops": [
      [
       7,
       14
      ],
      [
       11,
       24
      ]
     ]
    }
   },
   "paint": {
    "text-color": "#FFFFFF",
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.5
   }
  },
  {
   "id": "state",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "place",
   "maxzoom": 6,
   "filter": [
    "all",
    [
     "==",
     "class",
     "state"
    ]
   ],
   "layout": {
    "text-field": "{name}",
    "text-font": [
     "Roboto Condensed Italic"
    ],
    "text-size": {
     "stops": [
      [
       4,
       11
      ],
      [
       6,
       15
      ]
     ]
    },
    "text-transform": "uppercase"
   },
   "paint": {
    "text-color": "#FFFFFF",
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.5
   }
  },
  {
   "id": "country_3",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "place",
   "filter": [
    "all",
    [
     ">=",
     "rank",
     3
    ],
    [
     "==",
     "class",
     "country"
    ]
   ],
   "layout": {
    "text-field": "{name}",
    "text-font": [
     "Roboto Condensed Italic"
    ],
    "text-max-width": 6.25,
    "text-size": {
     "stops": [
      [
       3,
       11
      ],
      [
       7,
       17
      ]
     ]
    },
    "text-transform": "none"
   },
   "paint": {
    "text-color": "#FFFFFF",
    "text-halo-blur": 1,
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.5
   }
  },
  {
   "id": "country_2",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "place",
   "filter": [
    "all",
    [
     "==",
     "rank",
     2
    ],
    [
     "==",
     "class",
     "country"
    ]
   ],
   "layout": {
    "text-field": "{name}",
    "text-font": [
     "Roboto Condensed Italic"
    ],
    "text-max-width": 6.25,
    "text-size": {
     "stops": [
      [
       2,
       11
      ],
      [
       5,
       17
      ]
     ]
    },
    "text-transform": "none"
   },
   "paint": {
    "text-color": "#FFFFFF",
    "text-halo-blur": 1,
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.5
   }
  },
  {
   "id": "country_1",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "place",
   "filter": [
    "all",
    [
     "==",
     "rank",
     1
    ],
    [
     "==",
     "class",
     "country"
    ]
   ],
   "layout": {
    "text-field": "{name}",
    "text-font": [
     "Roboto Condensed Italic"
    ],
    "text-max-width": 6.25,
    "text-size": {
     "stops": [
      [
       1,
       11
      ],
      [
       4,
       17
      ]
     ]
    },
    "text-transform": "none"
   },
   "paint": {
    "text-color": "#FFFFFF",
    "text-halo-blur": 1,
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.5
   }
  },
  {
   "id": "continent",
   "type": "symbol",
   "source": "openmaptiles",
   "source-layer": "place",
   "maxzoom": 1,
   "filter": [
    "all",
    [
     "==",
     "class",
     "continent"
    ]
   ],
   "layout": {
    "text-field": "{name}",
    "text-font": [
     "Roboto Condensed Italic"
    ],
    "text-size": 13,
    "text-transform": "uppercase",
    "text-justify": "center"
   },
   "paint": {
    "text-color": "#FFFFFF",
    "text-halo-color": "rgba(13,24,48,0.92)",
    "text-halo-width": 1.5
   }
  }
 ],
 "id": "okventa-noche"
}
''';

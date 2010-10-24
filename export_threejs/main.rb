class ThreeJSExporter
  def initialize(filepath)
    @filepath = filepath
    @model = Sketchup.active_model
    @entities = @model.active_entities
  end
  
  def export
    File.open(@filepath, "w") do |file|
      file.write to_html
    end
  end

  private
  def title
    if @model.title.empty?
      "Untitled"
    else
      @model.title
    end
  end
  
  def faces
    faces = []
    @entities.each do |entity|
      faces.push entity if entity.is_a? Sketchup::Face
    end
    @model.definitions.each do |definition|
      definition.entities.each do |entity|
        faces.push entity if entity.is_a? Sketchup::Face
      end
    end
    faces
  end
  
  def meshes
    faces.map {|face| face.mesh }
  end
  
  def polygons
    meshes.inject([]) do |polygons, mesh|
      mesh.polygons.each do |polygon|
        polygons.push polygon.map {|point_nr| mesh.point_at(point_nr.abs) }
      end
      polygons
    end
  end
  
  def points
    polygons.inject([]) do |points, polygon|
      points.concat polygon
    end.uniq
  end
  
  def triangles
    ps = points
    polygons.map do |polygon|
      polygon.map {|point| ps.index point }
    end
  end
  
  def load_asset asset
    File.open(File.dirname(__FILE__) + "/" + asset, "r").read
  end
  
  def to_html
    return <<EOF
<!DOCTYPE html>
<html>
  <head>
    <title>#{title}</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width" />
    <style>
      #{load_asset "style.css"}
    </style>
  </head>
  <body>
    <div id="overlay">
      <h1>#{title}</h1>
    </div>
    #{to_html_snippet}
  </body>
</html>
EOF
  end
  
  def to_html_snippet
    return <<EOF
<div id="container"></div>
<script>
  #{load_asset "three.js"}
  #{load_asset "scene.js"}
  render(#{to_js});
</script>
EOF
  end
  
  def to_js
    return <<EOF
(function() {
  function Model() {
    THREE.Geometry.call(this);
    var self = this;
    
    function each(arr, fn) {
      for(var i = 0, l = arr.length; i < l; i++) {
        fn(arr[i], i);
      }
    }
    
    each([#{points.map {|p| "[#{p.x.to_f},#{p.y.to_f},#{p.z.to_f}]"}.join(',')}], function(point) {
      self.vertices.push(new THREE.Vertex(new THREE.Vector3(point[0], point[1], point[2])));
    });
    
    each([#{triangles.map {|t| "[#{t.join ','}]"}.join(',')}], function(triangle) {
      self.faces.push(new THREE.Face3(triangle[0], triangle[1], triangle[2]));
    });
    
    //function f3n( a, b, c, nx, ny, nz ) {
    //  scope.faces.push( new THREE.Face3( a, b, c, new THREE.Vector3( nx, ny, nz ) ) );
    //}
    //function uv(u1, v1, u2, v2, u3, v3) {
    //  scope.uvs.push( [ 
    //    new THREE.Vector2( u1, v1 ), 
    //    new THREE.Vector2( u2, v2 ), 
    //    new THREE.Vector2( u3, v3 ) 
    //  ]);
    //}
  }
  Model.prototype = new THREE.Geometry();
  Model.prototype.constructor = Model;
  Model.bounds = { width: #{@model.bounds.width.to_f}, height: #{@model.bounds.height.to_f}, depth: #{@model.bounds.depth.to_f} };
  
  window["#{title.gsub("\\", "\\\\").gsub('"', '\"').gsub(/\s/, "_").gsub(/[^A-Za-z1-9-_]/, '')}"] = Model;
  return Model;
})()
EOF
  end
end

UI.menu("File").add_item "Export to three.js" do
  title = Sketchup.active_model.title
  title = "Unnamed" if title.empty?
  filepath = UI.savepanel("Filename", nil, title + ".html")
  exporter = ThreeJSExporter.new filepath
  exporter.export
end

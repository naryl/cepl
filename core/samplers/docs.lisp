(in-package :cepl.samplers)

(docs:define-docs
  (defstruct sampler
    "
A sampler is a structure which holds texture 'sampling parameters' and can be
applied to textures to affect how data is read from them in shader pipelines.

Sampling is the process of fetching a value from a texture at a given position.
There are a number of values that can be tweaked that affect how the sampling is
done. These values can be set either on the texture itself or on a 'sampler'.


Sampling Parameters cover four main aspects of how the values are read:

- Wrapping
- Filtering
- LOD
- Comparison


We will dive into these topics below.

-- Note for beginners --
This area of GL can be incredibly confusing so don't worry if you don't grasp it
immediately. Lots can be done without messing with these values, tackle each
one when you have a usecase for it.


-- Wrapping --

When using normalized texture coordinates we are used to thinking about our
coordinate being between 0s0 and 1s0 and that value dictating where we are
sampling from.

However normalized texture coordinates are not limited to values between
0s0 and 1s0. They can be any floating-point number.

When a texture coordinate is not within the 0 → 1 range, some means must be
employed to decide what the color value will be.

The different approaches are as follows:

 :repeat: the texture coordinate wraps around the texture. so a texture
          coordinate of -0.2 becomes the equivalent of 0.8.

 :mirrored-repeat: the texture coordinate wraps around like a mirror.
                   -0.2 becomes 0.2, -1.2 becomes 0.8, etc.

 :clamp-to-edge: the texture coordinate is clamped to the 0 → 1 range.

 :clamp-to-border: the texture coordinate is clamped to the 0 → 1
                   range, but the edge texels are blended with a
                   constant border color.

 :mirror-clamp-to-edge: (only available with OpenGL 4.4 or
                        :arb-texture-mirror-clamp-to-edge) the texture
                        is clamped to the -1 → 1 range, but mirrors the
                        negative direction with the positive. Basically,
                        it acts as :clamp-to-edge, except that it
                        takes the absolute value of the texture
                        coordinates before clamping.

This also applies to Rectangle Textures, except that the range at which they
apply edge sampling is based on the texel width/height of the texture, not
the normalized 0 → 1 range.

This does not apply to Buffer Textures, as they must use the texelFetch sampling
functions and thus cannot sample outside of the texel range of the texture.

example:

    (setf (wrap texture-or-sampler)
          #(:clamp-to-edge :repeat-to-edge :clamp-to-edge))

    (setf (wrap texture-or-sampler) :clamp-to-edge)



-- Filtering --

Filtering is the process of accessing a particular sample from a texture.

There are two cases when filtering is relevant: minification and magnification.

Magnification means that the area of the fragment in texture space is smaller
than a texel, and minification means that the area of the fragment in texture
space is larger than a texel.

Filtering for these two cases can be set independently.

The magnification filter is controlled by the :magnify-filter texture parameter.
This value can be :linear or :nearest.

If :nearest is used, then the implementation will select the texel nearest the
texture coordinate; this is commonly called 'point sampling').

If :linear is used, the implementation will perform a weighted linear blend
between the nearest adjacent samples.

    (setf (magnify-filter tex-or-sampler) :linear)
    (setf (magnify-filter tex-or-sampler) :nearest)


The minification filter is controlled by the :texture-min-filter texture
parameter. To understand these values better, it is important to discuss what
the particular options are. Here is the full list:

:nearest                 :linear
:nearest-mipmap-nearest  :nearest-mipmap-linear
:linear-mipmap-nearest   :linear-mipmap-linear

When doing minification, you can choose to use mipmapping or not. Using
mipmapping means selecting between multiple mipmaps based on the angle and size
of the texture relative to the screen. Whether you use mipmapping or not,
you can still select between linear blending of the particular layer or nearest.
And if you do use mipmapping, you can choose to either select a single mipmap to
sample from, or you can sample the two adjacent mipmaps and linearly blend the
resulting values to get the final result.

The OpenGL minification settings for these are as follows:
Param Setting            Lin within mip-level
:nearest                 No
:linear                  Yes
:nearest-mipmap-nearest  No
:linear-mipmap-nearest   Yes
:nearest-mipmap-linear   No
:linear-mipmap-linear    Yes

Param Setting            Has mipmapping
:nearest                 No
:linear                  No
:nearest-mipmap-nearest  Yes
:linear-mipmap-nearest   Yes
:nearest-mipmap-linear   Yes
:linear-mipmap-linear    Yes

Param Setting            Linear between mip-levels
:nearest                 -
:linear                  -
:nearest-mipmap-nearest  No
:linear-mipmap-nearest   No
:nearest-mipmap-linear   Yes
:linear-mipmap-linear    Yes

Remembering these combinations can be annoying so CEPL provides an additional
function called #'set-minify-filter see the docstring for details

examples:

    (setf (minify-filter tex-or-sampler) :linear)
    (setf (minify-filter tex-or-sampler) :nearest-mipmap-nearest)
    (setf-minify-filter tex-or-sampler :nearest :nearest)


-- LOD --

There is a pair of sampling parameters that affect the mipmap image selection:
:max-lod and :min-lod (floating-point values).

The way these work in mipmap selection is quite complicated; the specification
goes into full detail about it.

example:

    (setf (min-lod texture-or-sampler) value)
    (setf (max-lod texture-or-sampler) value)


LOD bias:
The mipmap image selection process can be adjusted coarsely by using the
:lod-bias sampling parameter. This bias will be added to the mipmap
LOD calculation (as well as added to the bias specified in one of the texture
accessing functions in GLSL), which is used to select the image. A positive bias
means that larger mipmaps will be selected even when the texture is viewed from
farther away. This can cause visual aliasing, but in small quantities it can
make textures a bit more sharp.

    (setf (lod-bias texture-or-sampler) value)



-- Comparison --

-WARNING-

This feature is currently unsupported until shadow samplers are more fully
tested in CEPL. Use at your own risk


Depth textures (textures that have a depth component image format) can be
sampled in one of two ways. They can be sampled as a normal texture, which
simply retrieves the depth value (with filtering applied). This will return a
vec4 containing a single floating-point value.

They can also be fetched in comparison mode. This means that sampling from
the texture requires a value to compare to those pulled from the texture;
this value is called the reference value. The result of the comparison
depends on the comparison function set in the texture. If the function
succeeds, the resulting value is 1s0; if it fails, it is 0s0.

When linear filtering is used, the actual returned value is
implementation-defined. However, the value will be on the range 0 → 1 and
will be proportional to the number of neighboring texels that pass the
comparison based on the single given value.

If the texture is a normalized integer depth format, then the reference value
is clamped to 0 → 1, to match the values from the texture. Otherwise, the value
is not clamped.

Using this mode requires two special settings. First, the sampler used in GLSL
must be a shadow sampler. Second, the texture used in that sampler must have
activated depth comparison mode. Attempting to use a texture without comparison
with a shadow sampler, or vice-versa, will result in an error upon rendering.

To set the texture to comparison mode, set the :texture-compare-mode
texture parameter to :compare-ref-to-texture. The comparison function to
use when comparing the reference to the texture is set with the
:texture-compare-func texture parameter. Acceptable values are:

:never (always fails)
:always (always succeeds)
:less
:lequal
:equal,
:not-equal
:gequal
:greater

The comparison works as follows: (funcall operator ref texture)
Where ref is the reference value given to the texture lookup function by
GLSL, and texture is the value fetched from the texture. So :LESS will be
true if the reference value is strictly less than the value pulled from the
texture.
")

  (defun compare
      "
This function sets the comparison mode of the texture or sampler given

-WARNING-

This feature is currently unsupported until shadow samplers are more fully
tested in CEPL. Use at your own risk


-- Comparison --

Depth textures (textures that have a depth component image format) can be
sampled in one of two ways. They can be sampled as a normal texture, which
simply retrieves the depth value (with filtering applied). This will return a
vec4 containing a single floating-point value.

They can also be fetched in comparison mode. This means that sampling from
the texture requires a value to compare to those pulled from the texture;
this value is called the reference value. The result of the comparison
depends on the comparison function set in the texture. If the function
succeeds, the resulting value is 1s0; if it fails, it is 0s0.

When linear filtering is used, the actual returned value is
implementation-defined. However, the value will be on the range 0 → 1 and
will be proportional to the number of neighboring texels that pass the
comparison based on the single given value.

If the texture is a normalized integer depth format, then the reference value
is clamped to 0 → 1, to match the values from the texture. Otherwise, the value
is not clamped.

Using this mode requires two special settings. First, the sampler used in GLSL
must be a shadow sampler. Second, the texture used in that sampler must have
activated depth comparison mode. Attempting to use a texture without comparison
with a shadow sampler, or vice-versa, will result in an error upon rendering.

To set the texture to comparison mode, set the :texture-compare-mode
texture parameter to :compare-ref-to-texture. The comparison function to
use when comparing the reference to the texture is set with the
:texture-compare-func texture parameter. Acceptable values are:

:never (always fails)
:always (always succeeds)
:less
:lequal
:equal,
:not-equal
:gequal
:greater

The comparison works as follows: (funcall operator ref texture)
Where ref is the reference value given to the texture lookup function by
GLSL, and texture is the value fetched from the texture. So :LESS will be
true if the reference value is strictly less than the value pulled from the
texture.
")

  (defun lod-bias
      "
This function sets the lod-bias of the given texture or sampler


-- LOD --

There is a pair of sampling parameters that affect the mipmap image selection:
:max-lod and :min-lod (floating-point values).

The way these work in mipmap selection is quite complicated; the specification
goes into full detail about it.

example:

    (setf (min-lod texture-or-sampler) value)
    (setf (max-lod texture-or-sampler) value)


LOD bias:
The mipmap image selection process can be adjusted coarsely by using the
:lod-bias sampling parameter. This bias will be added to the mipmap
LOD calculation (as well as added to the bias specified in one of the texture
accessing functions in GLSL), which is used to select the image. A positive bias
means that larger mipmaps will be selected even when the texture is viewed from
farther away. This can cause visual aliasing, but in small quantities it can
make textures a bit more sharp.

    (setf (lod-bias texture-or-sampler) value)
")

  (defun magnify-filter
      "
This function takes a sampler or texture and sets the approach used when the
area of the fragment in texture space is smaller than a texel.


-- The magnification filter --

The magnification filter is controlled by the :magnify-filter texture parameter.
This value can be :linear or :nearest.

If :nearest is used, then the implementation will select the texel nearest the
texture coordinate; this is commonly called 'point sampling').

If :linear is used, the implementation will perform a weighted linear blend
between the nearest adjacent samples.

    (setf (magnify-filter tex-or-sampler) :linear)
    (setf (magnify-filter tex-or-sampler) :nearest)
")

  (defun minify-filter
      "
This function takes a sampler or texture and sets the approach used when the
area of the fragment in texture space is larger than a texel.

-- The minification filter --

The minification filter is controlled by the :texture-min-filter texture
parameter. To understand these values better, it is important to discuss what
the particular options are. Here is the full list:

:nearest                 :linear
:nearest-mipmap-nearest  :nearest-mipmap-linear
:linear-mipmap-nearest   :linear-mipmap-linear

When doing minification, you can choose to use mipmapping or not. Using
mipmapping means selecting between multiple mipmaps based on the angle and size
of the texture relative to the screen. Whether you use mipmapping or not,
you can still select between linear blending of the particular layer or nearest.
And if you do use mipmapping, you can choose to either select a single mipmap to
sample from, or you can sample the two adjacent mipmaps and linearly blend the
resulting values to get the final result.

The OpenGL minification settings for these are as follows:
Param Setting            Lin within mip-level
:nearest                 No
:linear                  Yes
:nearest-mipmap-nearest  No
:linear-mipmap-nearest   Yes
:nearest-mipmap-linear   No
:linear-mipmap-linear    Yes

Param Setting            Has mipmapping
:nearest                 No
:linear                  No
:nearest-mipmap-nearest  Yes
:linear-mipmap-nearest   Yes
:nearest-mipmap-linear   Yes
:linear-mipmap-linear    Yes

Param Setting            Linear between mip-levels
:nearest                 -
:linear                  -
:nearest-mipmap-nearest  No
:linear-mipmap-nearest   No
:nearest-mipmap-linear   Yes
:linear-mipmap-linear    Yes

Remembering these combinations can be annoying so CEPL provides an additional
function called #'set-minify-filter see the docstring for details

examples:

    (setf (minify-filter tex-or-sampler) :linear)
    (setf (minify-filter tex-or-sampler) :nearest-mipmap-nearest)
    (setf-minify-filter tex-or-sampler :nearest :nearest)

")

  (defun set-minify-filter
      "
As the naming of the values for #'minify-filter are quite confusing this
function allows you to set the minify filter for the given texture or sampler
based on the following:

- for-level: what sampling should be used between texels on the current
             mipmap level. The value can be :linear or :nearest

- between-level: what sampling should be used between texels on different
                 mipmap levels. The value can be :linear or :nearest
                 This argument is optional.
")

  (defun max-lod
      "
This function sets the max-lod of the given texture or sampler


-- LOD --

Together with :min-lod this sampling parameter affects the mipmap image
selection.

The way these work in mipmap selection is quite complicated; the specification
goes into full detail about it.

example:

    (setf (min-lod texture-or-sampler) value)
    (setf (max-lod texture-or-sampler) value)
")

    (defun min-lod
      "
This function sets the min-lod of the given texture or sampler


-- LOD --

Together with :max-lod this sampling parameter affects the mipmap image
selection.

The way these work in mipmap selection is quite complicated; the specification
goes into full detail about it.

example:

    (setf (min-lod texture-or-sampler) value)
    (setf (max-lod texture-or-sampler) value)
")

    (defun wrap
	"
This function sets the wrap parameter of the texture or sampler given.

When setf'ing this parameter you can provide either one approach to be used
for all 3 potential dimensions of the texture, or you can provide a vector
of the 3 approaches you want to used.


-- Wrapping --

When using normalized texture coordinates we are used to thinking about our
coordinate being between 0s0 and 1s0 and that value dictating where we are
sampling from.

However normalized texture coordinates are not limited to values between
0s0 and 1s0. They can be any floating-point number.

When a texture coordinate is not within the 0 → 1 range, some means must be
employed to decide what the color value will be.

The different approaches are as follows:

 :repeat: the texture coordinate wraps around the texture. so a texture
          coordinate of -0.2 becomes the equivalent of 0.8.

 :mirrored-repeat: the texture coordinate wraps around like a mirror.
                   -0.2 becomes 0.2, -1.2 becomes 0.8, etc.

 :clamp-to-edge: the texture coordinate is clamped to the 0 → 1 range.

 :clamp-to-border: the texture coordinate is clamped to the 0 → 1
                   range, but the edge texels are blended with a
                   constant border color.

 :mirror-clamp-to-edge: (only available with OpenGL 4.4 or
                        :arb-texture-mirror-clamp-to-edge) the texture
                        is clamped to the -1 → 1 range, but mirrors the
                        negative direction with the positive. Basically,
                        it acts as :clamp-to-edge, except that it
                        takes the absolute value of the texture
                        coordinates before clamping.

This also applies to Rectangle Textures, except that the range at which they
apply edge sampling is based on the texel width/height of the texture, not
the normalized 0 → 1 range.

This does not apply to Buffer Textures, as they must use the texelFetch sampling
functions and thus cannot sample outside of the texel range of the texture.

example:

    (setf (wrap texture-or-sampler)
          #(:clamp-to-edge :repeat-to-edge :clamp-to-edge))

    (setf (wrap texture-or-sampler) :clamp-to-edge)


")

    (defun make-sampler
	"
Make-sampler creates a new texture sampler that can be used to override the
sampling parameters of a texture.

For details on what a sampler is and what the parameters are and mean see the
docstring for the 'sampler type
")

    (defun sampler-p
	"
This function returns t if the supplied value is a sampler and nil otherwise
")

    (defmacro with-sampling
	"
This macro is how you apply override a texture's sampling parameters.

The sampler affects any sampling done by pipelines run inside the scope of
with-sampling. After the scope the sampler is detatched.

with-sampling is used as follows:

    (with-sampling ((*tex* *sam*)
                    (*tex2* *sam*))
      (map-g #'prog-1 *stream* :tex *tex* :norm-map *tex2*))

Where *sam* is a sampler that is attached to both of the textures *tex* and
*tex2*

See https://github.com/cbaggers/cepl.examples/blob/master/examples/sampling.lisp
for a full example.
"))

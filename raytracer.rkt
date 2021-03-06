
;; Sample Work : Ray Tracer in Racket/Scheme, built for CS 151 sequence fall 2012
;; Rebeca Carrillo




;;Notes:

;; I chose this project because it was the most well-organized example I had of 
;; most of my preferred approaches to larger-ish projects (writing tests, developing in
;; modules, using match patterns to make refactoring easier, etc.)


;; Highlights, Takeaways, etc. from this particular project

;; Write Tests
;; This course required contracts and tests for each function, which was tedious, 
;; but getting disciplined about being consistent/systematic was super valuable. 
;; I've found that writing tests consistently 
;; throughout the process makes things go much more straightforwardly in the long run.

;; Brainstorm vs Slow Burn / Don't write code with a raised heartrate
;; This was the first time I learned 
;; Brainstorming and systematic building are different creatures.

;; Going back over activity logs and revisions at the end of a long project 
;; is helpful for me to see what I actually learned --
;;  my pain points were, if I followed a pattern, etc.

;;
;; For example, I tend to group things less formally now-- here I have "data definitons"
;; "tests", and I developed those functions in those exact categories. 
;;   The process could have been improved if I had understood more deeply what these things
;;  were for, instead of just what they were called. 





;; Things I Would Do Differently

;; Talk Out Loud/Comment Insanity
;; - When I began building this, I didn't allow myself to just create a huge file with
;;  psuedocode and instructions for myself/brainstorms, etc, partially because
;;  I was afraid of making a mess, revealing my inexperience, etc. I wish I had. I think 
;;  if had been less concerned with it looking pretty at each step I would have learned 
;;  a lot more sooner.

;; Write plans down
;;  - this project took up too much brainpower for what it was, mostly because
;;  I tried to keep too many things in my head. I consistently lost time on little things like
;;  trying to remember where I had intended to go with a function, not understanding 
;;   my own comments, etc.  Poor Planning = anxiety.  

;;  Not use Racket
;;  - parens for days


(require 2htdp/image)
(require racket/match)


;; ===== data definitions ====== ;; 

;; a vec3 is a (make-vec3 x y z) where x, y, z numbers
(define-struct vec3 (x y z))

;; an rgb is a (make-rgb r g b) where r, g, b are numbers on [0.0,1.0]
(define-struct rgb (r g b))

;; a sphere is a (make-sphere center radius color)
;; where center is a vec3, radius is a num, color is an rgb
(define-struct sphere (center radius color))

;; a light is a (make-light v color)
;; where v is a vec3 (a vector pointing at the light)
;; and color is an rgb
(define-struct light (v color))

;; a scene is a (make-scene bg-color objs light amb)
;; where bg-color is a color, objs is a list of objects,
;; light is a light, and amb is an rgb
(define-struct scene (bg-color objs light amb))

;; a camera is a (make-camera z img-w img-h)
;; where z, img-w and img-h are numbers
;; camera is located at (0,0,z)
;; z is typically a small negative number, like -2
(define-struct camera (z img-w img-h))

;; a hit-test is either
;; - 'miss, or
;; - (make-hit dist surf-color surf-normal)
;;     where dist is a num, surf-color is an rgb, and
;;     surf-normal is a (unit) vec3
(define-struct hit (dist surf-color surf-normal))

;; === operations on vectors ===

;; vec3+ : vec3 vec3 -> vec3
(define (vec3+ u v)
  (match* (u v)
    [((struct vec3 (x y z)) (struct vec3 (X Y Z)))
     (make-vec3 (+ x X) (+ y Y) (+ z Z))]))

(check-expect (vec3+ (make-vec3 0 1 2) (make-vec3 4 8 16))
              (make-vec3 4 9 18))

;; vec3- : vec3 vec3 -> vec3
(define (vec3- u v)
  (vec3+ u (vec3-neg v)))

(check-expect (vec3- (make-vec3 0 1 2) (make-vec3 4 8 16))
              (make-vec3 -4 -7 -14))

;; vec3-neg : vec3 -> vec3
(define (vec3-neg v)
  (vec3-scale -1 v))

(check-expect (vec3-neg (make-vec3 1 2 -3))
              (make-vec3 -1 -2 3))

;; vec3-scale : num vec3 -> vec3
(define (vec3-scale s v)
  (match v
    [(struct vec3 (x y z))
     (make-vec3 (* s x) (* s y) (* s z))]))

(check-expect (vec3-scale 2 (make-vec3 1 2 4))
              (make-vec3 2 4 8))

;; vec3-dot : vec3 vec3 -> num
(define (vec3-dot u v)
  (match* (u v)
    [((struct vec3 (x y z)) (struct vec3 (X Y Z)))
     (+ (* x X) (* y Y) (* z Z))]))

(check-expect (vec3-dot (make-vec3 0 1 2) (make-vec3 4 8 16))
              40)

;; vec3-mag : vec3 -> num
(define (vec3-mag v)
  (sqrt (vec3-dot v v)))

(check-expect (vec3-mag (make-vec3 3 4 0)) 5)

;; vec3-norm : vec3 -> vec3
(define (vec3-norm v)
  (local {(define l (vec3-mag v))}
    (if (< (* l l) 0.000001) 
        (make-vec3 0 0 0)
        (vec3-scale (/ 1 l) v))))

(check-expect (vec3-mag (vec3-norm (make-vec3 0.0000001 0.00000001 0.000000001))) 0)
(check-within (vec3-mag (vec3-norm (make-vec3 123 -234 789))) 1 0.000001)

;; === operations on rgb colors ===

;; color->rgb : color -> rgb
(define (color->rgb c)
  (local {(define (f sel) (/ (sel c) 255))}
    (make-rgb (f color-red)
              (f color-green)
              (f color-blue))))

;; black? : color -> bool
(define (black? c)
  (local {(define (z s) (= 0 (s c)))}
    (and (z color-red) (z color-green) (z color-blue))))

;; name->color : (+ symbol string) -> color
(define (name->color s)
  (local {(define q (square 1 "solid" s))
          (define c (first (image->color-list q)))
          (define s* (if (symbol? s) (symbol->string s) s))}
    (if (and (black? c) (not (string-ci=? s* "black")))
        (error 'name->color (string-append "unknown color name: " s*))
        c)))

;; name->rgb : (+ symbol string) -> rgb
(define name->rgb (compose color->rgb name->color))

(check-expect (name->rgb "blue") (make-rgb 0 0 1))

;; rgb->color : rgb -> color
(define (rgb->color c)
  (local {(define (f s) (inexact->exact (floor (* 255 (s c)))))}
    (make-color (f rgb-r) (f rgb-g) (f rgb-b))))

;; rgb-apply-to-components : ((rgb -> num) -> num) -> rgb
;; apply component transformer to all selectors of rgb
(define (rgb-apply-to-components f)
  (make-rgb (f rgb-r) (f rgb-g) (f rgb-b)))

;; rgb-modulate : rgb rgb -> rgb
(define (rgb-modulate c1 c2)
  (rgb-apply-to-components (λ (s) (* (s c1) (s c2)))))

;; rgb-scale : num rgb -> rgb
(define (rgb-scale x c)
  (rgb-apply-to-components (λ (s) (min 1 (* x (s c))))))

;; rgb+ : rgb rgb -> rgb
(define (rgb+ c1 c2)
  (rgb-apply-to-components (λ (s) (min 1 (+ (s c1) (s c2))))))

;; color-matrix->img : (listof (listof color)) -> img
;; pre: color-matrix regular (not jagged)
(define (color-matrix->img css)
  (local {(define h (length css))
          (define w (length (first css)))}
    (color-list->bitmap (foldr append empty css) w h)))

;; rgb-matrix->color-matrix (listof (listof rgb)) -> (listof (listof color))
(define (rgb-matrix->color-matrix rss)
  (map (λ (rs) (map rgb->color rs)) rss))

;; rgb-matrix->img : (listof (listof rgb)) -> img
(define rgb-matrix->img 
  (compose color-matrix->img rgb-matrix->color-matrix))

;; === operations on rays ===

;; a ray is a (make-ray origin dir)
;; where origin is a vec3 (representing a position), and
;;       direction is a unit vec3
(define-struct ray (origin dir))

;; ray-position : ray num -> vec3
(define (ray-position r t)
  (match r 
    [(struct ray (o d)) (vec3+ o (vec3-scale t d))]))

(check-expect (ray-position (make-ray (make-vec3 0 0 0) (make-vec3 1 0 0)) 10)
              (make-vec3 10 0 0))

(check-expect (ray-position (make-ray (make-vec3 0 0 0) (make-vec3 0 1 0)) 10)
              (make-vec3 0 10 0))

(check-expect (ray-position (make-ray (make-vec3 0 0 0) (make-vec3 0 0 1)) 10)
              (make-vec3 0 0 10))

;; === rgb color constants, predefined for convenience ===

(define rgb:white      (make-rgb 1 1 1))
(define rgb:black      (make-rgb 0 0 0))
(define rgb:gray       (make-rgb 38/51 38/51 38/51))
(define rgb:darkgray   (make-rgb 169/255 169/255 169/255))
(define rgb:red        (make-rgb 1 0 0))
(define rgb:green      (make-rgb 0 1 0))
(define rgb:blue       (make-rgb 0 0 1))
(define rgb:pink       (make-rgb 1 64/85 203/255))
(define rgb:silver     (make-rgb 64/85 64/85 64/85))
(define rgb:ivory      (make-rgb 1 1 16/17))
(define rgb:orange     (make-rgb 1 11/17 0))
(define rgb:dodgerblue (make-rgb 2/17 48/85 1))
(define rgb:skyblue    (make-rgb 9/17 206/255 47/51))
(define rgb:navy       (make-rgb 36/255 36/255 140/255))

;; === ray tracer guts ===

;; miss? : anything -> bool
(define (miss? x)
  (and (symbol? x) (symbol=? 'miss x)))

;; match-posn : posn -> (listof num)
;; thing I have to write because posns don't "match"
(define (match-posn p) (list (posn-x p) (posn-y p)))

;; logical-loc : camera posn -> vec3
;; raise an error if phys-loc out of bounds
(define (logical-loc c phys-loc)
  (match* (c (match-posn phys-loc))
    [((camera z iw ih) (list phys-x phys-y))
     (if (or (< phys-x 0) (< phys-y 0) (>= phys-x iw) (>= phys-y ih))
         (error 'logical-loc "out of bounds")
         (local 
           {(define larger-dimension (if (> iw ih) iw ih))
            (define logical-pixel-side (/ 2 larger-dimension))
            (define logical-left 
              (if (> iw ih) -1 (- (* (/ iw 2) logical-pixel-side))))
            (define logical-top 
              (if (> iw ih) (* (/ ih 2) logical-pixel-side) 1))
            (define x
              (+ logical-left 
                 (* phys-x logical-pixel-side) (/ logical-pixel-side 2)))
            (define y 
              (- logical-top 
                 (* phys-y logical-pixel-side) (/ logical-pixel-side 2)))}
           (make-vec3 x y 0)))]))

(check-expect (logical-loc (make-camera -1 10 10) (make-posn 0 0))
              (make-vec3 -0.9 0.9 0))

(check-expect (logical-loc (make-camera -1 30 20) (make-posn 0 0))
              (make-vec3 (+ -1 1/30) (- 2/3 1/30) 0))

(check-expect (logical-loc (make-camera -1 30 20) (make-posn 1 0))
              (make-vec3 -0.9 (- 2/3 1/30) 0))

(check-expect (logical-loc (make-camera -1 30 20) (make-posn 29 19))
              (make-vec3 (- 1 1/30) (+ -2/3 1/30) 0)) 

(check-expect (logical-loc (make-camera -1 10 14) (make-posn 0 0))
              (make-vec3 (+ -5/7 1/14) (- 1 1/14) 0))

(check-expect (logical-loc (make-camera -1 10 14) (make-posn 0 13))
              (make-vec3 (+ -5/7 1/14) (+ -1 1/14) 0))

(check-error (logical-loc (make-camera -1 10 14) (make-posn 10 0)))

(check-error (logical-loc (make-camera -1 10 14) (make-posn 0 14)))

(check-error (logical-loc (make-camera -1 10 14) (make-posn -1 0)))

;; intersect : ray sphere -> hit-test
(define (intersect r s)
  (match* (r s)
    [((ray ro rd) (sphere sc sr sk))
     (local
       {(define dst (vec3- ro sc))
        (define b (vec3-dot dst rd))
        (define c (- (vec3-dot dst dst) (sqr sr)))
        (define d (- (sqr b) c))}
       (if (> d 0)
           (local
             {(define t (- (- b) (sqrt d)))
              (define sn ;; surface normal
                (vec3-norm (vec3- (ray-position r t) sc)))}
             (if (<= t 0)
                 'miss
                 (make-hit t sk sn)))
           'miss))]))

(check-expect 
 (intersect 
  (make-ray (make-vec3 0 0 -1) (make-vec3 0 0 1))
  (make-sphere (make-vec3 0 0 1) 1 (make-rgb 0.8 0 0)))
 (make-hit 1 (make-rgb 0.8 0 0) (make-vec3 0 0 -1)))

;; sh? : vec3 light -> (sphere -> bool)
;; test if position p, given directional light, is shadowed by sphere s
(define (sh? p l)
  (λ (s)
    (match l
      [(light lv lk)
       (local
         {(define r (make-ray (vec3+ p (vec3-scale 0.0001 lv)) lv))}
         (hit? (intersect r s)))])))
  
(check-expect 
 ((sh? (make-vec3 0 0 1)
       (make-light (make-vec3 0 0 -1) (make-rgb 1 1 1)))
  (make-sphere (make-vec3 0 0 0) 0.5 (make-rgb 1 0 0)))
 true)

(check-expect 
 ((sh? (make-vec3 0 0 1)
       (make-light (make-vec3 0 0 -1) (make-rgb 1 1 1)))
  (make-sphere (make-vec3 0 0 3) 0.5 (make-rgb 1 0 0)))
 false)

;; shadowed? : vec3 light (listof sphere) -> bool
;; is position p, given light l, shadowed by any of the spheres?
(define (shadowed? p l ss)
  (ormap (sh? p l) ss))

(check-expect (shadowed? (make-vec3 0 0 0)
                         (make-light (make-vec3 0 1 0) (make-rgb 1 1 1))
                         (list
                          (make-sphere (make-vec3 0 10 0) 0.1 (make-rgb 0 0 0))))
               true)

(check-expect (shadowed? (make-vec3 0 0 10)
                         (make-light (make-vec3 0 1 0) (make-rgb 1 1 1))
                         (list
                          (make-sphere (make-vec3 0 10 0) 0.1 (make-rgb 0 0 0))))
               false)

;; lighting : scene ray hit-test -> rgb
;; compute color of pixel given ray
;; precondition: ray starts at camera, passes through view plane
(define (lighting s r t)
  (match s
    [(scene s-bg s-ss (light lv lk) s-amb)
     (match t
       ['miss s-bg]
       [(hit hd hk hn)
        (local 
          {(define hit-loc (ray-position r hd))}
          (if (shadowed? hit-loc (make-light lv lk) s-ss)
              (rgb-modulate hk s-amb)
              (local
                {(define diffuse (rgb-scale (max 0 (vec3-dot hn lv)) lk))}
                (rgb-modulate hk (rgb+ s-amb diffuse)))))])]))

;; -- lighting tests --

(define test-camera (make-camera -5 200 200))

(define test-sphere-1 (make-sphere (make-vec3 0 0 3) 1 rgb:red))
(define test-sphere-2 (make-sphere (make-vec3 1 0 5) 1 rgb:orange))
(define test-sphere-3 (make-sphere (make-vec3 1 -1 4) 2 rgb:orange))
(define test-sphere-4 (make-sphere (make-vec3 -1 1 2.75) 0.6 rgb:blue))

(define test-scene-1
  (make-scene
   rgb:black
   (list test-sphere-1)
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.2 0.2 0.2)))

(define test-scene-2
  (make-scene
   rgb:black
   (list test-sphere-1 test-sphere-2)
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.2 0.2 0.2)))

(define test-scene-3
  (make-scene
   rgb:black
   (list test-sphere-3 test-sphere-4)
   (make-light (vec3-norm (make-vec3 -1 1 -0.5)) rgb:white)
   (make-rgb 0.2 0.2 0.3)))

(check-expect 
 (local
   {(define r (make-ray (make-vec3 0 0 -5) (make-vec3 0 0 1)))}
   (rgb->color (lighting test-scene-1 r (intersect r test-sphere-1))))
 (make-color 198 0 0))

(check-expect
 (local
   {(define r (make-ray (make-vec3 0 0 -5) (make-vec3 0 0 1)))}
   (rgb->color (lighting test-scene-2 r (intersect r test-sphere-1))))
 (make-color 198 0 0))

(check-expect 
 (local
   {(define r (make-ray (make-vec3 0 0 -5) (vec3-norm (make-vec3 0.1 0 1))))}
   (rgb->color (lighting test-scene-2 r (intersect r test-sphere-1))))
 (make-color 51 0 0))

(check-expect 
 (local
   {(define r (make-ray (make-vec3 0 0 -5) (vec3-norm (make-vec3 0.1 0.05 1))))}
   (rgb->color (lighting test-scene-2 r (intersect r test-sphere-1))))
 (make-color 77 0 0))

;; closest-sphere : ray (listof sphere) -> hit-test
(define (closest-sphere r ss)
  (local
    {;; (+ num 'inf) (+ num 'inf) -> bool
     ;; comparison of numbers with "infinitely large" quantity as well
     (define (<< a b)
       (cond
         [(and (symbol? a) (symbol? b)) (error '<< "both inf")]
         [(symbol? b) true]
         [else (< a b)]))
     ;; lp : (listof sphere) num sphere -> hit-test
     ;; return hit closest to ray's origin, or 'miss for no spheres
     (define (lp ss dist closest)
       (if (empty? ss)
           closest
           (local
             {(define t (intersect r (first ss)))}
             (if (hit? t)
                 (if (<< (hit-dist t) dist)
                     (lp (rest ss) (hit-dist t) t)
                     (lp (rest ss) dist closest))
                 (lp (rest ss) dist closest)))))}
    (lp ss 'inf 'miss)))

;; tests of closest sphere

(check-expect 
 (closest-sphere (make-ray (make-vec3 0 0 -1) (make-vec3 0 0 1))
                 (list test-sphere-1 test-sphere-2))
 (make-hit 3 (make-rgb 1 0 0) (make-vec3 0 0 -1)))
 
(check-expect 
 (closest-sphere (make-ray (make-vec3 0 0 -1) (make-vec3 0 0 1))
                 (list test-sphere-2 test-sphere-1))
 (make-hit 3 (make-rgb 1 0 0) (make-vec3 0 0 -1)))

(check-expect
 (closest-sphere (make-ray (make-vec3 0 0 -1) (make-vec3 0 0 1)) empty)
 'miss)

;; trace-ray : scene ray -> rgb
(define (trace-ray s r)
  (match s [(scene _ ss _ _) 
    (lighting s r (closest-sphere r ss))]))
     ;;(local {(define x (closest-sphere r ss))}
       ;;(if (hit? x) (lighting s r x) bg))]))

;; build-image : nat nat (nat nat -> rgb) -> img
(define (build-image w h f)
  (rgb-matrix->img (build-list h (λ (y) (build-list w (λ (x) (f x y)))))))

;; ray-through : vec3 vec3 -> ray
(define (ray-through src dst)
  (make-ray src (vec3-norm (vec3- dst src))))

;; render-scene : camera scene -> rgb-matrix
(define (render-scene c s)
  (match c
    [(camera z w h)
     (local
       {(define co (make-vec3 0 0 z))
        (define (trace-through-pixel x y)
          (match (logical-loc c (make-posn x y))
            [pixel-center
               (trace-ray s (ray-through co pixel-center))]))}
       (build-image w h trace-through-pixel))]))




;;; === TESTS ===
;
;(render-scene test-camera test-scene-1)
;(render-scene test-camera test-scene-2)
;(render-scene test-camera test-scene-3)



;; === Test Gallery ===

(define cs151-12-test-camera-0 (make-camera -5 80 80))
(define cs151-12-test-camera-1 (make-camera -5 200 200))
(define cs151-12-test-camera-2 (make-camera -8 200 200))
(define cs151-12-test-camera-3 (make-camera -8 400 400))

;; === scenes

(define cs151-12-test-scene-1
  (make-scene
   rgb:darkgray
   (list 
    (make-sphere (make-vec3 0 0 3) 1 rgb:orange))
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.2 0.2 0.2)))

(define cs151-12-test-scene-2
  (make-scene
   rgb:darkgray
   (list 
    (make-sphere (make-vec3 0 0 6) 1 rgb:orange))
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.2 0.2 0.2)))

(define cs151-12-test-scene-3
  (make-scene
   rgb:navy
   (list 
    (make-sphere (make-vec3 0 0 6) 1 rgb:pink))
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.2 0.2 0.2)))

(define cs151-12-test-scene-4
  (make-scene
   rgb:navy
   (list 
    (make-sphere (make-vec3  3/2 0 8) 1 rgb:dodgerblue)
    (make-sphere (make-vec3 -3/2 0 8) 1 rgb:dodgerblue))
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.2 0.2 0.2)))

(define cs151-12-test-scene-5
  (make-scene
   rgb:black
   (list 
    (make-sphere (make-vec3  3/2 0 8)  1 rgb:dodgerblue)
    (make-sphere (make-vec3 -3/2 0 8)  1 rgb:dodgerblue)
    (make-sphere (make-vec3    0 0 20) 1 rgb:silver))
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.2 0.2 0.2)))

(define cs151-12-test-scene-6
  (make-scene
   rgb:black
   (list 
    (make-sphere (make-vec3    1  -1  8) 1 rgb:dodgerblue)
    (make-sphere (make-vec3   -1   1  8) 1 rgb:dodgerblue))
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.2 0.2 0.2)))

(define cs151-12-test-scene-7
  (make-scene
   rgb:black
   (list 
    (make-sphere (make-vec3    1    -1  8) 2 rgb:ivory)
    (make-sphere (make-vec3   -1/3   1  5) 3/4 rgb:ivory))
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.2 0.2 0.2)))

(define cs151-12-test-scene-8
  (make-scene
   rgb:black
   (list 
    (make-sphere (make-vec3    1    -1  8) 2  rgb:ivory)
    (make-sphere (make-vec3   -1/3   1  5) 3/4  rgb:ivory))
   (make-light (vec3-norm (make-vec3 -1/2 1/1 -1))  rgb:red)
   (make-rgb 0.2 0.2 0.2)))

(define cs151-12-test-scene-9
  (make-scene
   rgb:black
   (list 
    (make-sphere (make-vec3 1 1 8) 2/3 rgb:gray)
    (make-sphere (make-vec3 0 0 1) 1/2 rgb:skyblue))
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.2 0.2 0.2)))

(define cs151-12-test-scene-A
  (make-scene
   (make-rgb 0.1 0.1 0.35)
   (build-list 20 
               (λ (i) (make-sphere (make-vec3 1/2 (sub1 (/ i 5)) i) 
                                   1/5 
                                   (make-rgb (/ i 20) 0 (/ (- 20 i) 20)))))
   (make-light (vec3-norm (make-vec3 -1 1 -1)) rgb:white)
   (make-rgb 0.3 0.2 0.2)))
    
;; === render scenes with various cameras ===

;(render-scene cs151-12-test-camera-1 cs151-12-test-scene-1)
;(render-scene cs151-12-test-camera-1 cs151-12-test-scene-2)
;(render-scene cs151-12-test-camera-1 cs151-12-test-scene-3)
;(render-scene cs151-12-test-camera-1 cs151-12-test-scene-4)
;(render-scene cs151-12-test-camera-1 cs151-12-test-scene-5)
;(render-scene cs151-12-test-camera-1 cs151-12-test-scene-6)
;(render-scene cs151-12-test-camera-1 cs151-12-test-scene-7)
;(render-scene cs151-12-test-camera-1 cs151-12-test-scene-8)
;(render-scene cs151-12-test-camera-2 cs151-12-test-scene-8)
;(render-scene cs151-12-test-camera-3 cs151-12-test-scene-8)
;(render-scene cs151-12-test-camera-0 cs151-12-test-scene-9)
;(render-scene cs151-12-test-camera-1 cs151-12-test-scene-9)
;(render-scene cs151-12-test-camera-2 cs151-12-test-scene-9)
;(render-scene cs151-12-test-camera-3 cs151-12-test-scene-9)
;(render-scene cs151-12-test-camera-2 cs151-12-test-scene-A)
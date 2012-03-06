;;;; -*- Mode: Lisp; indent-tabs-mode: nil -*-

(defsystem :static-vectors
  :description "Create vectors allocated in static memory."
  :author "Stelian Ionescu <sionescu@cddr.org>"
  :licence "MIT"
  :version #.(with-open-file (f (merge-pathnames "../version.lisp-expr"
                                                 (or *compile-file-pathname*
                                                     *load-truename*)))
               (read f))
  :defsystem-depends-on (#+(or allegro cmu ecl sbcl) :cffi-grovel)
  :depends-on (:alexandria :cffi)
  :components ((:file "pkgdcl")
               (:file "constantp" :depends-on ("pkgdcl"))
               (:file "initialize" :depends-on ("pkgdcl" "constantp"))
               #+(or allegro cmu ecl sbcl)
               (:cffi-grovel-file "ffi-types" :depends-on ("pkgdcl"))
               (:file "impl"
                      :depends-on ("pkgdcl" "constantp" "initialize"
                                   #+(or allegro cmu ecl sbcl) "ffi-types")
                      :pathname #+allegro   "impl-allegro"
                                #+ccl       "impl-clozure"
                                #+cmu       "impl-cmucl"
                                #+ecl       "impl-ecl"
                                #+lispworks "impl-lispworks"
                                #+sbcl      "impl-sbcl")
               (:file "constructor" :depends-on ("pkgdcl" "constantp" "initialize" "impl"))
               (:file "cffi-type-translator" :depends-on ("pkgdcl" "impl"))))

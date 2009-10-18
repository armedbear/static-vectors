;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil -*-
;;;
;;; --- Allegro CL implementation.
;;;

(in-package :static-vectors)

(declaim (inline fill-foreign-memory))
(defun fill-foreign-memory (pointer length value)
  "Fill LENGTH octets in foreign memory area POINTER with VALUE."
  (foreign-funcall "memset" :pointer pointer :int value :int length :pointer)
  pointer)

(declaim (inline copy-foreign-memory))
(defun copy-foreign-memory (src-ptr dst-ptr length)
  "Copy LENGTH octets from foreign memory area SRC-PTR to DST-PTR."
  (foreign-funcall "memcpy" :pointer dst-ptr :pointer src-ptr :int length :pointer)
  dst-ptr)

(declaim (inline %allocate-static-vector))
(defun %allocate-static-vector (length element-type initial-element)
  (make-array length :allocation :static
              :element-type element-type
              :initial-element initial-element))

(defun make-static-vector (length &key (element-type '(unsigned-byte 8))
                           (initial-element 0 initial-element-p))
  "Create a simple vector of length LENGTH and type ELEMENT-TYPE which will
not be moved by the garbage collector. The vector might be allocated in
foreign memory so you must always call FREE-STATIC-VECTOR to free it."
  (declare (optimize speed))
  (check-type length non-negative-fixnum)
  (let ((actual-initial-element
         (%choose-initial-element element-type initial-element initial-element-p)))
    (%allocate-static-vector length element-type actual-initial-element)))

(define-compiler-macro make-static-vector (&whole whole &environment env
                                           length &key (element-type ''(unsigned-byte 8))
                                           (initial-element 0 initial-element-p))
  (cond
    ((constantp element-type env)
     (let ((element-type (eval element-type)))
       (let ((actual-initial-element
              (if (constantp initial-element env)
                  (%choose-initial-element element-type (eval initial-element) initial-element-p)
                  `(%choose-initial-element ',element-type ,initial-element ,initial-element-p))))
         (if (constantp length env)
             (let ((%length% (eval length)))
               (check-type %length% non-negative-fixnum)
               `(%allocate-static-vector ,%length% ',element-type ,actual-initial-element))
             (with-gensyms (%length%)
               `(let ((,%length% ,length))
                  (check-type ,%length% non-negative-fixnum)
                  (%allocate-static-vector ,%length% ',element-type ,actual-initial-element)))))))
    (t whole)))

(declaim (inline static-vector-address))
(defun static-vector-address (vector)
  "Return a foreign pointer to VECTOR(including its header).
VECTOR must be a vector created by MAKE-STATIC-VECTOR."
  (excl:lispval-other-to-address vector))

(declaim (inline static-vector-pointer))
(defun static-vector-data-pointer (vector)
  "Return a foreign pointer to VECTOR's data.
VECTOR must be a vector created by MAKE-STATIC-VECTOR."
  (ff:fslot-address-typed :unsigned-char :lisp vector))

(declaim (inline free-static-vector))
(defun free-static-vector (vector)
  "Free VECTOR, which must be a vector created by MAKE-STATIC-VECTOR."
  (excl:aclfree (static-vector-address vector))
  (values))

(defmacro with-static-vector ((var length &rest args
                               &key (element-type ''(unsigned-byte 8)) (initial-element 0))
                              &body body)
  "Bind PTR-VAR to a static vector of length LENGTH and execute BODY
within its dynamic extent. The vector is freed upon exit."
  (declare (ignore element-type initial-element))
  `(let ((,var nil))
     (unwind-protect
          (progn
            (setf ,var (make-static-vector ,length ,@args))
            ,@body)
       (when ,var (free-static-vector ,var)))))
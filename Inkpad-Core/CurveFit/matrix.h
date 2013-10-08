#ifndef __Geom_MATRIX_H__
#define __Geom_MATRIX_H__

/** \file
 * Definition of Geom::Matrix types.
 *
 * Main authors:
 *   Lauris Kaplinski <lauris@kaplinski.com>:
 *     Original NRMatrix definition and related macros.
 *
 *   Nathan Hurst <njh@mail.csse.monash.edu.au>:
 *     Geom::Matrix class version of the above.
 *
 *   Michael G. Sloan <mgsloan@gmail.com>:
 *     Reorganization and additions.
 *
 * This code is in public domain.
 */

//#include <glib/gmessages.h>

#include "transforms.h"
#include "math-utils.h"

namespace Geom {

/**
 * The Matrix class.
 * 
 * For purposes of multiplication, points should be thought of as row vectors
 *
 * \f$(p_X p_Y 1)\f$
 *
 * to be right-multiplied by transformation matrices of the form
 * \f[
   \left[
   \begin{array}{ccc}
    c_0&c_1&0 \\
    c_2&c_3&0 \\
    c_4&c_5&1
   \end{array}
   \right]
   \f]
 * (so the columns of the matrix correspond to the columns (elements) of the result,
 * and the rows of the matrix correspond to columns (elements) of the "input").
 */
class Matrix {
    Coord _c[6];

  public:

    //TODO: I'd prefer it default to identity matrix - Botty
    explicit Matrix() { }

    Matrix(Matrix const &m) {
        for(int i = 0; i < 6; i++) {
            _c[i] = m[i];
        }
    }

    Matrix(Coord c0, Coord c1, Coord c2, Coord c3, Coord c4, Coord c5) {
        _c[0] = c0; _c[1] = c1;
        _c[2] = c2; _c[3] = c3;
        _c[4] = c4; _c[5] = c5;
    }

    Matrix &operator=(Matrix const &m) {
        for(int i = 0; i < 6; i++)
            _c[i] = m._c[i];
        return *this;
    }

    explicit Matrix(Scale const &sm) {
        _c[0] = sm[X];
        _c[3] = sm[Y];
    }

    explicit Matrix(Rotate const &r) {
        set_x_axis(r.vec);
        set_y_axis(r.vec.cw());
    }

    explicit Matrix(Translate const &tm) {
        set_translation(tm.offset);
    }

    Point x_axis() const;
    Point y_axis() const;
    Point translation() const;
    void set_x_axis(Point const &vec);
    void set_y_axis(Point const &vec);
    void set_translation(Point const &loc);

    //TODO: Remove testing code from production code! matrix.cpp as well
    bool test_identity() const;

    bool is_translation(Coord const eps = Geom_EPSILON) const;
    bool is_rotation(double const eps = Geom_EPSILON) const;
    bool is_scale(double const eps = Geom_EPSILON) const;
    bool is_uniform_scale(double const eps = Geom_EPSILON) const;

    Matrix inverse() const;

    Matrix &operator*=(Matrix const &other);
    Matrix &operator*=(Scale const &other);
    Matrix &operator*=(Translate const &other);

    inline Coord &operator[](int const i) {
        return _c[i];
    }

    inline Coord operator[](int const i) const {
        return _c[i];
    }

    //TODO: change name to reset? just create a new matrix?
    void set_identity();
	
    Coord det() const;
    Coord descrim2() const;
    Coord descrim() const;

    double expansion() const;
    //TODO: change to get/set_x/y_length?
    double expansionX() const;
    double expansionY() const;
	
    // legacy
    //TODO: Remove
    Matrix &assign(Coord const *array);
    Coord *copyto(Coord *array) const;
};

/** A function to print out the Matrix (for debugging) */
inline std::ostream &operator<< (std::ostream &out_file, const Geom::Matrix &m) {
    out_file << "A: " << m[0] << "  C: " << m[2] << "  E: " << m[4] << "\n";
    out_file << "B: " << m[1] << "  D: " << m[3] << "  F: " << m[5] << "\n";
    return out_file;
}

extern void assert_close(Matrix const &a, Matrix const &b);

/** Given a matrix m such that unit_circle = m*x, this returns the
 * quadratic form x*A*x = 1. */
Matrix elliptic_quadratic_form(Matrix const &m);

/** Given a matrix (ignoring the translation) this returns the eigen
 * values and vectors. */
class Eigen{
public:
    Point vectors[2];
    Point values;    //TODO: Shouldn't be Point?
    Eigen(Matrix const &m);
};

// Matrix factories
Matrix from_basis(const Point x_basis, const Point y_basis, const Point offset=Point(0,0));

Matrix identity();

double expansion(Matrix const &m);

bool transform_equalp(Matrix const &m0, Matrix const &m1, Geom::Coord const epsilon);
bool translate_equalp(Matrix const &m0, Matrix const &m1, Geom::Coord const epsilon);
bool matrix_equalp(Matrix const &m0, Matrix const &m1, Geom::Coord const epsilon);

Matrix without_translation(Matrix const &m);
Translate to_translate(Matrix const &m);

void matrix_print(const char *say, Matrix const &m);

inline bool operator==(Matrix const &a, Matrix const &b) {
    for(unsigned i = 0; i < 6; ++i) {
        if ( a[i] != b[i] ) {
            return false;
        }
    }
    return true;
}

inline bool operator!=(Matrix const &a, Matrix const &b) { return !( a == b ); }
Matrix operator*(Matrix const &a, Matrix const &b);

} /* namespace Geom */

#endif /* !__Geom_MATRIX_H__ */

/*
  Local Variables:
  mode:c++
  c-file-style:"stroustrup"
  c-file-offsets:((innamespace . 0)(inline-open . 0)(case-label . +))
  indent-tabs-mode:nil
  fill-column:99
  End:
*/
// vim: filetype=cpp:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:encoding=utf-8:textwidth=99 :

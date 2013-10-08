#include "transforms.h"

namespace Geom {

//***************
//Scale operators

/** Multiplies a Scale with a Translate.
 \return a Matrix which Scales, and then Translates.
 */
Matrix operator*(Scale const &s, Translate const &t) {
    Matrix ret(s);
    ret.set_translation(t.offset);

    assert_close( ret, Matrix(s) * t );
    return ret;
}

/** Multiplies a Scale with a Matrix.
 \return a Matrix where the x and y axii have been Scaled.
 */
Matrix operator*(Scale const &s, Matrix const &m) {
    Matrix ret(m);
    ret[0] *= s[X];
    ret[1] *= s[X];
    ret[2] *= s[Y];
    ret[3] *= s[Y];

    assert_close( ret, Matrix(s) * m );
    return ret;
}

//***************
//Rotate operators

/** Multiplies a rotation with a Matrix. */
Matrix operator*(Rotate const &a, Matrix const &b) {
    return Matrix(a) * b;
}



//****************
//Translate operators


/** Multiplies a Translate with a Scale.
 \return a Matrix which not only Translates by the Scaled translation, but also includes the scaling.
 */
Matrix operator*(Translate const &t, Scale const &s) {
    Matrix ret(s);
    ret[4] = t[X] * s[X];
    ret[5] = t[Y] * s[Y];

    assert_close( ret, Matrix(t) * Matrix(s) );
    return ret;
}

/** Multiplies a Translate with a Rotate.
 \return a Matrix which not only Translates by the Rotated translation, but also includes the rotation.
 */
Matrix operator*(Translate const &t, Rotate const &r) {
    Matrix ret(r);
    ret.set_translation(t.offset * ret);

    assert_close( ret, Matrix(t) * Matrix(r) );
    return ret;
}


//****************
//Matrix operators

/** Multiplies a Matrix with a Scale, scaling up every aspect of the transformation. */ 
Matrix operator*(Matrix const &m, Scale const &s) {
    Matrix ret(m);
    ret[0] *= s[X]; ret[1] *= s[Y];
    ret[2] *= s[X]; ret[3] *= s[Y];
    ret[4] *= s[X]; ret[5] *= s[Y];

    assert_close( ret, m * Matrix(s) );
    return ret;
}

/** Divides a Matrix by a Scale.  This is the same thing as multiplying by the inverse of the Scale. */
Matrix operator/(Matrix const &m, Scale const &s) {
    Geom::Matrix ret(m);
    ret[0] /= s[X]; ret[1] /= s[Y];
    ret[2] /= s[X]; ret[3] /= s[Y];
    ret[4] /= s[X]; ret[5] /= s[Y];

    assert_close( ret, m * Matrix(s.inverse()) );
    return ret;
}

/** Multiplies a Matrix with a rotation. */
Matrix operator*(Matrix const &m, Rotate const &r) {
  return m * Matrix(r);
}

/** Multiplies a Matrix with a translation, effectively adding the translation to the matrix. */
Matrix operator*(Matrix const &m, Translate const &t) {
    Matrix ret(m);
    ret[4] += t[X];
    ret[5] += t[Y];

    assert_close( ret, m * Matrix(t) );
    return ret;
}

/** Multiplies two matrices together, effectively combining their transformations.*/
Matrix operator*(Matrix const &m0, Matrix const &m1) {
    Matrix ret;
    for(int a = 0; a < 5; a += 2) {
        for(int b = 0; b < 2; b++) {
            ret[a + b] = m0[a] * m1[b] + m0[a + 1] * m1[b + 2];
        }
    }
    ret[4] += m1[4];
    ret[5] += m1[5];
    return ret;
}

Matrix operator/(Matrix const &a, Matrix const &b) { return a * b.inverse(); }

}

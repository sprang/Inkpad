#ifndef SEEN_Geom_TRANSFORMS_H
#define SEEN_Geom_TRANSFORMS_H

#include "rotate.h"
#include "scale.h"
#include "translate.h"
#include "matrix.h"

namespace Geom {

//TODO: All the overloads, compounds!

//Matrix operator*(Scale const &s, Rotate const &r);
//Matrix operator/(Scale const &s, Rotate const &r);
Matrix operator*(Scale const &s, Translate const &t);
//Matrix operator/(Scale const &s, Translate const &t);
Matrix operator*(Scale const &s, Matrix const &m);
//Matrix operator/(Scale const &s, Matrix const &m);

//Matrix operator*(Rotate const &a, Scale const &b);
//Matrix operator/(Rotate const &a, Scale const &b);
//Matrix operator*(Rotate const &a, Translate const &b);
//Matrix operator/(Rotate const &a, Translate const &b);
Matrix operator*(Rotate const &a, Matrix const &b);
//Matrix operator/(Rotate const &a, Matrix const &b);

Matrix operator*(Translate const &t, Scale const &s);
Matrix operator/(Translate const &t, Scale const &s);
Matrix operator*(Translate const &t, Rotate const &r);
Matrix operator/(Translate const &t, Rotate const &r);
Matrix operator*(Translate const &t, Matrix const &m);
//Matrix operator/(Translate const &t, Matrix const &m);

Matrix operator*(Matrix const &m, Translate const &t);
//Matrix operator/(Matrix const &m, Translate const &t);
Matrix operator*(Matrix const &m, Scale const &s);
Matrix operator/(Matrix const &m, Scale const &s);
Matrix operator*(Matrix const &m, Rotate const &r);
//Matrix operator/(Matrix const &m, Rotate const &r);
Matrix operator*(Matrix const &m1, Matrix const &m2);
Matrix operator/(Matrix const &a, Matrix const &b);

} /* namespace Geom */


#endif /* !SEEN_Geom_TRANSFORMS_H */

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

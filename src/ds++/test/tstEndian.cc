//----------------------------------*-C++-*----------------------------------//
/*!
 * \file   ds++/test/tstEndian.cc
 * \author Mike Buksas
 * \date   Tue Oct 23 16:20:59 2007
 * \brief  
 * \note   Copyright (C) 2006-2013 Los Alamos National Security, LLC.
 *         All rights reserved.
 */
//---------------------------------------------------------------------------//
// $Id$
//---------------------------------------------------------------------------//

#include "../ScalarUnitTest.hh"
#include "../Release.hh"
#include "../Endian.hh"
#include <sstream>
#include <limits>

using namespace std;
using namespace rtt_dsxx;

//---------------------------------------------------------------------------//
// TESTS
//---------------------------------------------------------------------------//
void test_char_data(ScalarUnitTest& ut)
{

    unsigned char data[] = {'a', 'b', 'c'};
    unsigned int length = sizeof(data)/sizeof(unsigned char);

    char_byte_swap(data, length);

    if ((data[0] != 'c') || (data[1] != 'b') || (data[2] != 'a'))
        ut.failure("unsigned char_byte_swap function failed");

    /* plain */ char pdata[] = {'a', 'b', 'c'};
    unsigned int plength = sizeof(pdata)/sizeof(/* plain */ char);

    char_byte_swap(pdata, plength);

    if ((pdata[0] != 'c') || (pdata[1] != 'b') || (pdata[2] != 'a'))
        ut.failure("plain char_byte_swap function failed");
    
}

void test_integer(ScalarUnitTest& ut)
{

    // Integer. This value overflows unsigned ints.
    int moo = 0xDEADBEEF;

    byte_swap(moo);

    if (static_cast<unsigned>(moo) != 0xEFBEADDE)
        ut.failure("byte_swap failed for for integer type");

    // Unsigned integer
    unsigned int u_moo = 0xDEADBEEF;

    byte_swap(u_moo);

    if (u_moo != 0xEFBEADDE)
        ut.failure("byte_swap failed for for unsigned integer type");

}


void test_idempotence(ScalarUnitTest& ut)
{
    
    /* This test demonstrates that two applications of byte-swap in succession
     * return the original value.
     *
     * To do this, we sweep over a lot of double values. We use a non-integral
     * multiplier for successive values to avoid small subsets of the
     * available patterns of bits. E.g. multiples of 2.
     */ 

    for (double value = 1.0;
         value < std::numeric_limits<double>::max();
         value *= 3.4)
    {

        // Use the in-place version to test positive values.
        double local = value;
        byte_swap(local);   
        byte_swap(local);

        // These numbers should be identical, so I'm testing for equality.
        if (local != value)
            ut.failure("byte_swap failed to reproduce original number");


        // Use the copy-generating version to test negative numbers.

        const double neg_local = byte_swap_copy( byte_swap_copy( -value ) );

        if (neg_local != -value)
            ut.failure("byte_swap failed to reproduce original number");

    }

}

//---------------------------------------------------------------------------//

void test_ieee_float(ScalarUnitTest& ut)
{
    // These tests always pass, but they may print different messages.

    // Endianess
    if( is_big_endian() )
        ut.passes( "This machine uses big endian byte ordering." );
    else
        ut.passes( "This machine uses little endian byte ordering." );

    // IEEE floating point?
    if( has_ieee_float_representation() )
    {
        std::ostringstream msg;
        msg << "Looks like we are on a platform that supports IEEE "
            << "floating point representation.";
        ut.passes( msg.str() );
    }
    else
    {
        std::ostringstream msg;
        msg << "This platform does not support IEEE floating point "
            << "representation.";
        ut.passes( msg.str() );
    }
}

//---------------------------------------------------------------------------//

int main(int argc, char *argv[])
{
    rtt_dsxx::ScalarUnitTest ut(argc, argv, release);
    try
    {
        test_char_data(ut);
        test_integer(ut);
        test_idempotence(ut);
        test_ieee_float(ut);
        ut.passes("Just Because.");
    }
    UT_EPILOG(ut);
}   

//---------------------------------------------------------------------------//
// end of tstEndian.cc
//---------------------------------------------------------------------------//

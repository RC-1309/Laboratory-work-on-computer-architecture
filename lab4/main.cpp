#include <bits/stdc++.h>
#include <omp.h>
using namespace std;

// omp_get_thread_num()
// omp_get_num_threads()

int main() {
    int c = 0;
#pragma omp parallel
    for (int i = 0; i < 1; i++) {
#pragma omp atomic
        c++;
    }
    cout << c << "\n";
    int k = 0;
    for (int i = 0; i < 30000; i++) {
        k += i;
    }
    printf("%i ()\n", k);
    k = 0;
#pragma omp parallel for
    for (int i = 0; i < 30000; i++) {
#pragma omp critical
        {
            k += i;
        }
    }
    printf("%i (%i)\n", k, omp_get_thread_num());
    k = 0;
    double tendstart = omp_get_wtime();
#pragma omp parallel
    {
        int ki = 0;
#pragma omp for
        for (int i = 0; i < 30000; i++) {
            ki += i;
//#pragma omp atomic
//#pragma omp critical
//            {
//                k += i;
//            }
        }
#pragma omp atomic
        k += ki;
//        printf("Hey %i/%i\n",
//               omp_get_thread_num(),
//               omp_get_num_threads());
    }
    double tend = omp_get_wtime();
    printf("%i (%i) %f sec\n", k, omp_get_thread_num(), tend-tendstart);
}
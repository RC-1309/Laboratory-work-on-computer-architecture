#include <iostream>
#include <fstream>
#include <omp.h>
#include <vector>
#include <iomanip>
using namespace std;

const int INF = 1e9;
const int num_of_starts = 100;

double sum_time = 0.0;
int chunk_size;
bool flag_for_test = true;
uint8_t *arr;
size_t length;
size_t w, h, n;
int thresholds0, thresholds1, thresholds2;
size_t num_of_colors;
size_t colors[256], pref_sum_p[257];
double pref_sum_average[257];

double get_dispersion(int a, int b) {
    double u = (pref_sum_average[b + 1] - pref_sum_average[a]);
    return u * u / (double)(pref_sum_p[b + 1] - pref_sum_p[a]);
}

double check(int a, int b, int c) {
    return (get_dispersion(0, a) + get_dispersion(a + 1, b))
           + (get_dispersion(b + 1, c) + get_dispersion(c + 1, (int)num_of_colors));
}

void without_openmp(int pos) {
    double tend_start = omp_get_wtime();
    for (int i = pos; i < length; i++) if (flag_for_test) colors[arr[i]]++;
    for (int i = 0; i <= num_of_colors; i++) pref_sum_p[i + 1] = pref_sum_p[i] + colors[i];
    for (int i = 0; i <= num_of_colors; i++) pref_sum_average[i + 1] = pref_sum_average[i] + (double)colors[i] * (double)i / (double)n;
    double mx = -INF;
    for (int f0 = 0; f0 <= num_of_colors - 3; f0++) {
        for (int f1 = f0 + 1; f1 <= num_of_colors - 2; f1++) {
            for (int f2 = f1 + 1; f2 <= num_of_colors - 1; f2++) {
                double num = check(f0, f1, f2);
                if (mx <= num) {
                    mx = num;
                    thresholds0 = f0; thresholds1 = f1; thresholds2 = f2;
                }
            }
        }
//        cout << mx << " " << thresholds0 << " " << thresholds1 << " " << thresholds2 << "\n";
    }
    for (int i = pos; i < length; i++) {
        int c = arr[i];
        if (c <= thresholds0) arr[i] = 0;
        else if (c <= thresholds1) arr[i] = 84;
        else if (c <= thresholds2) arr[i] = 170;
        else arr[i] = 255;
    }
    double time_ = omp_get_wtime() - tend_start;
    cout << thresholds0 << " " << thresholds1 << " " << thresholds2 << "\n";
    sum_time += time_;
    printf("Without parallel: %f ms\n", time_ * 1000);
}

void parallel(int pos) {
    double tend_start = omp_get_wtime();
    int num_of_threads;
#pragma omp parallel
    {
        num_of_threads = omp_get_num_threads();
        size_t colors_i[num_of_colors + 1];
        for (int i = 0; i <= num_of_colors; i++) colors_i[i] = 0;
#pragma omp for nowait
        for (int i = pos; i < length; i++) colors_i[arr[i]]++;
#pragma omp critical
        for (int i = 0; i <= num_of_colors; i++) if (flag_for_test) colors[i] += colors_i[i];
    }
    for (int i = 0; i <= num_of_colors; i++) pref_sum_p[i + 1] = pref_sum_p[i] + colors[i];
    for (int i = 0; i <= num_of_colors; i++) pref_sum_average[i + 1] = pref_sum_average[i] + (double)colors[i] * (double)i;
    double mx = -INF;
#pragma omp parallel
    {
        double max_i = -INF;
        int t0, t1, t2;
        for (int f0 = 0; f0 <= num_of_colors - 3; f0++) {
            for (int f1 = f0 + 1; f1 <= num_of_colors - 2; f1++) {
#pragma omp for nowait schedule(runtime)
                for (int f2 = f1 + 1; f2 <= num_of_colors - 1; f2++) {
                    double num = check(f0, f1, f2);
                    if (max_i <= num) {
                        max_i = num;
                        t0 = f0;
                        t1 = f1;
                        t2 = f2;
                    }
                }
            }
//            cout << f0 << ": " << max_i << " " << t0 << " " << t1 << " " << t2 << " " << omp_get_thread_num() << "\n";
        }
#pragma omp critical
        {
            if (mx < max_i) {
                mx = max_i;
                thresholds0 = t0;
                thresholds1 = t1;
                thresholds2 = t2;
            }
        }
    }
#pragma omp parallel
    {
        int color;
#pragma omp for
        for (int i = pos; i < length; i++) {
            if (arr[i] <= thresholds0) color = 0;
            else if (arr[i] <= thresholds1) color = 84;
            else if (arr[i] <= thresholds2) color = 170;
            else color = 255;
            if (flag_for_test) arr[i] = color;
        }
    }
    double time_ = omp_get_wtime() - tend_start;
//    cout << mx << '\n';
//    cout << thresholds0 << " " << thresholds1 << " " << thresholds2 << "\n";
    sum_time += time_;
//    printf("Time (%i thread(s)): %f ms\n", num_of_threads, time_ * 1000);
}

void solve(int num_of_treads, int pos) {
    for (int i = 8; i < 9; i++) {
        num_of_treads = i;
        if (num_of_treads > 0) omp_set_num_threads(num_of_treads);
        for (int j = 1; j < 252; j += 10) {
            chunk_size = j;
            sum_time = 0.0;
            for (int ii = 0; ii < num_of_starts; ii++) {
                if (num_of_treads == -1) {
                    without_openmp(pos);
                } else {
                    parallel(pos);
                }
                flag_for_test = false;
            }
            cout << i << " " << j <<  ": average time: " << sum_time / (double) num_of_starts * 1000 << " ms\n";
        }
    }
}

size_t get_number(int &pos) {
    size_t a = 0;
    while (pos < length && arr[pos] - '0' >= 0 && arr[pos] - '0' < 10) {
        a *= 10;
        a += arr[pos] - '0';
        pos++;
    }
    return a;
}

int main(int argc, char *argv[]) {
    cout << setprecision(10) << fixed;
    if (argc < 4) {
        cout << "Missing argument";
        return 0;
    }
    int num_of_treads;
    try {
        num_of_treads = stoi(argv[1]);
    } catch (...) {
        cout << "Invalid number of treads: " << argv[1];
    }
    try {
        ifstream in(argv[2], ifstream::binary);
        in.exceptions(ifstream::failbit);
        in.seekg(0, in.end);
        length = in.tellg();
        in.seekg(0, in.beg);
        arr = new uint8_t[length];
        in.read((char*) arr, length);
        in.close();
    } catch (const ifstream::failure& e) {
        cerr << "IO exception: " << e.what();
        return 0;
    }
    if (length < 8) {
        cerr << "File not full";
        return 0;
    }
    if (arr[0] != 'P' || arr[1] != '5') {
        cerr << "Incorrect file";
        return 0;
    }
    int pos = 3;
    w = get_number(pos);
    pos++;
    h = get_number(pos);
    pos++;
    num_of_colors = get_number(pos);
    n = h * w;
    solve(num_of_treads, pos + 1);
    try {
        ofstream out(argv[3], ofstream::binary);
        out.exceptions(ofstream::failbit);
        for (int i = 0; i < length; i++) {
            out << arr[i];
        }
        out.close();
    } catch (const ofstream::failure& e) {
        cerr << "Exception with output file: " << e.what();
        return 0;
    }
    return 0;
}
